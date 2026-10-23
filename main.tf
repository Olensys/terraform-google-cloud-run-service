locals {
  extra_labels = { for k, v in var.context.extra_tags :
  substr(replace(lower(k), "/[^a-z0-9_-]/", "-"), 0, 63) => substr(replace(lower(v), "/[^a-z0-9_-]/", "-"), 0, 63) }
  labels = merge(local.extra_labels, var.labels)

  create_sa = var.create && var.service_account_email == null
  sa_email  = var.create ? (var.service_account_email != null ? var.service_account_email : try(google_service_account.this[0].email, null)) : null
  sa_member = local.sa_email == null ? null : "serviceAccount:${local.sa_email}"

  # Full secret names for IAM, short ids expanded into the module project.
  secret_names = toset([
    for s in values(var.secret_env) :
    startswith(s, "projects/") ? s : "projects/${var.project_id}/secrets/${s}"
  ])

  has_triggers     = var.create && length(var.eventarc_triggers) > 0
  has_gcs_triggers = var.create && length([for t in var.eventarc_triggers : t if t.bucket != null]) > 0
  sa_account_id    = replace(substr(var.name, 0, 30), "/-+$/", "")
}

# Cloud Storage triggers publish through Pub/Sub; the project's Cloud Storage
# service agent needs roles/pubsub.publisher for that.
data "google_storage_project_service_account" "gcs" {
  count = local.has_gcs_triggers ? 1 : 0

  project = var.project_id
}

resource "google_project_iam_member" "gcs_pubsub_publisher" {
  count = local.has_gcs_triggers ? 1 : 0

  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs[0].email_address}"
}

resource "google_service_account" "this" {
  # Not planned for an account id the provider would reject; output.service_account_email reports why.
  count = local.create_sa && length(local.sa_account_id) >= 6 ? 1 : 0

  project      = var.project_id
  account_id   = local.sa_account_id
  display_name = "Cloud Run service ${var.name}"
}

resource "google_cloud_run_v2_service" "this" {
  count = var.create ? 1 : 0

  project             = var.project_id
  name                = var.name
  location            = var.region
  launch_stage        = "GA"
  ingress             = var.ingress
  deletion_protection = var.context.environment == "prod"
  labels              = local.labels

  template {
    service_account                  = local.sa_email
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = var.scaling.concurrency
    labels                           = local.labels

    scaling {
      min_instance_count = var.scaling.min
      max_instance_count = var.scaling.max
    }

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.resources.cpu
          memory = var.resources.memory
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        tcp_socket {
          port = var.port
        }
      }
    }

    dynamic "vpc_access" {
      for_each = var.vpc == null ? [] : [var.vpc]
      content {
        egress = vpc_access.value.egress
        network_interfaces {
          network    = vpc_access.value.network
          subnetwork = vpc_access.value.subnet
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.runtime]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.create ? toset(var.invoker_members) : toset([])

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_secret_manager_secret_iam_member" "runtime" {
  for_each = var.create ? local.secret_names : toset([])

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = local.sa_member
}

resource "google_project_iam_member" "eventarc_receiver" {
  count = local.has_triggers ? 1 : 0

  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = local.sa_member
}

resource "google_cloud_run_v2_service_iam_member" "eventarc_invoker" {
  count = local.has_triggers ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this[0].name
  role     = "roles/run.invoker"
  member   = local.sa_member
}

resource "google_eventarc_trigger" "this" {
  for_each = var.create ? var.eventarc_triggers : {}

  project         = var.project_id
  name            = "${var.name}-${each.key}"
  location        = var.region
  service_account = local.sa_email
  labels          = local.labels

  matching_criteria {
    attribute = "type"
    value     = each.value.event_type
  }

  dynamic "matching_criteria" {
    for_each = each.value.bucket == null ? [] : [each.value.bucket]
    content {
      attribute = "bucket"
      value     = matching_criteria.value
    }
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.this[0].name
      region  = var.region
    }
  }

  dynamic "transport" {
    for_each = each.value.pubsub_topic == null ? [] : [each.value.pubsub_topic]
    content {
      pubsub {
        topic = transport.value
      }
    }
  }

  depends_on = [
    google_project_iam_member.eventarc_receiver,
    google_project_iam_member.gcs_pubsub_publisher,
    google_cloud_run_v2_service_iam_member.eventarc_invoker,
  ]
}
