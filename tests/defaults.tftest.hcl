mock_provider "google" {}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name       = "example-app"
  project_id = "example-project"
  region     = "europe-west1"
  image      = "us-docker.pkg.dev/cloudrun/container/hello"
}

run "test_no_public_invoker_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.invoker) == 0
    error_message = "No invoker members may exist by default."
  }

  assert {
    condition     = !contains([for k, m in google_cloud_run_v2_service_iam_member.invoker : m.member], "allUsers")
    error_message = "allUsers must not be an invoker by default."
  }
}

run "test_public_invoker_needs_ingress_all" {
  command = plan

  variables {
    invoker_members = ["allUsers"]
  }

  expect_failures = [output.uri]
}

run "test_public_invoker_allowed_with_ingress_all" {
  command = plan

  variables {
    invoker_members = ["allUsers"]
    ingress         = "INGRESS_TRAFFIC_ALL"
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.invoker) == 1
    error_message = "allUsers invoker is allowed with INGRESS_TRAFFIC_ALL."
  }
}

run "test_secret_env_grants_accessor" {
  command = plan

  variables {
    secret_env = {
      DB_PASSWORD = "db-password"
      DB_REPLICA  = "db-password"
      API_KEY     = "projects/other-project/secrets/api-key"
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.runtime) == 2
    error_message = "One accessor grant per distinct secret."
  }

  assert {
    condition     = toset(output.secret_ids) == toset(["projects/example-project/secrets/db-password", "projects/other-project/secrets/api-key"])
    error_message = "Short ids expand to the module project; full names are kept."
  }

  assert {
    condition     = alltrue([for m in google_secret_manager_secret_iam_member.runtime : m.role == "roles/secretmanager.secretAccessor"])
    error_message = "Runtime SA gets secretAccessor."
  }
}

run "test_secret_env_conflicts_with_env" {
  command = plan

  variables {
    env        = { API_KEY = "x" }
    secret_env = { API_KEY = "api-key" }
  }

  expect_failures = [output.uri]
}

run "test_eventarc_per_trigger" {
  command = plan

  variables {
    eventarc_triggers = {
      uploads = { event_type = "google.cloud.storage.object.v1.finalized", bucket = "my-bucket" }
      events  = { event_type = "google.cloud.pubsub.topic.v1.messagePublished", pubsub_topic = "projects/example-project/topics/t" }
    }
  }

  assert {
    condition     = length(google_eventarc_trigger.this) == 2
    error_message = "One Eventarc trigger per map entry."
  }

  assert {
    condition     = length(google_project_iam_member.eventarc_receiver) == 1
    error_message = "Event receiver role granted once when triggers exist."
  }

  assert {
    condition     = google_eventarc_trigger.this["uploads"].name == "example-app-uploads"
    error_message = "Trigger names are <name>-<key>."
  }
}

run "test_no_eventarc_receiver_without_triggers" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.eventarc_receiver) == 0 && length(google_eventarc_trigger.this) == 0
    error_message = "No Eventarc resources without triggers."
  }
}

run "test_eventarc_storage_requires_bucket" {
  command = plan

  variables {
    eventarc_triggers = {
      uploads = { event_type = "google.cloud.storage.object.v1.finalized" }
    }
  }

  expect_failures = [var.eventarc_triggers]
}

run "test_ingress_validation" {
  command = plan

  variables {
    ingress = "ALL"
  }

  expect_failures = [var.ingress]
}

run "test_default_ingress_internal_lb" {
  command = plan

  assert {
    condition     = output.ingress_setting == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    error_message = "Default ingress is internal load balancer."
  }
}

run "test_vpc_egress_validation" {
  command = plan

  variables {
    vpc = { network = "n", subnet = "s", egress = "NONE" }
  }

  expect_failures = [var.vpc]
}

run "test_two_instances_distinct_role_names" {
  command = plan

  variables {
    name = "app-one"
  }

  assert {
    condition     = google_service_account.this[0].account_id == "app-one"
    error_message = "SA account id derives from name."
  }
}

run "test_two_instances_distinct_role_names_second" {
  command = plan

  variables {
    name = "app-two"
  }

  assert {
    condition     = google_service_account.this[0].account_id == "app-two" && google_service_account.this[0].account_id != "app-one"
    error_message = "A second instance gets a different SA account id."
  }
}

run "test_sa_account_id_trimmed" {
  command = plan

  variables {
    name = "abcdefghijklmnopqrstuvwxyz-abcdefghij"
  }

  assert {
    condition     = google_service_account.this[0].account_id == "abcdefghijklmnopqrstuvwxyz-abc"
    error_message = "Account id is truncated to 30 characters."
  }
}

run "test_sa_account_id_trailing_hyphen" {
  command = plan

  variables {
    name = "abcdefghijklmnopqrstuvwxyz-ab-cdefghij"
  }

  assert {
    condition     = google_service_account.this[0].account_id == "abcdefghijklmnopqrstuvwxyz-ab"
    error_message = "Trailing hyphen after truncation is trimmed."
  }
}

run "test_external_service_account" {
  command = plan

  variables {
    service_account_email = "runtime@example-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_service_account.this) == 0 && output.service_account_email == "runtime@example-project.iam.gserviceaccount.com"
    error_message = "Provided SA is used and none is created."
  }
}

run "test_name_length_validation" {
  command = plan

  variables {
    name = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwx"
  }

  expect_failures = [var.name]
}

run "test_name_49_accepted" {
  command = plan

  variables {
    name = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvw"
  }

  assert {
    condition     = output.name == "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvw"
    error_message = "49 characters is accepted."
  }
}

run "test_scaling_validation" {
  command = plan

  variables {
    scaling = { min = 5, max = 2 }
  }

  expect_failures = [var.scaling]
}

run "test_prod_deletion_protection" {
  command = plan

  variables {
    context = {
      organization = "olensys"
      environment  = "prod"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
    }
  }

  assert {
    condition     = google_cloud_run_v2_service.this[0].deletion_protection == true
    error_message = "Deletion protection is on in prod."
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = output.id == null && output.name == null && output.self_link == null && output.uri == null && output.service_account_email == null && output.labels == null && output.ingress_setting == null && output.secret_ids == null
    error_message = "Every output is null when create is false."
  }

  assert {
    condition     = length(google_cloud_run_v2_service.this) == 0 && length(google_service_account.this) == 0
    error_message = "No resources when create is false."
  }
}

run "test_tags_contract" {
  command = plan

  variables {
    labels = { owner = "x" }
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { Owner = "y", Team = "Core Team" }
    }
  }

  assert {
    condition     = output.labels.owner == "x"
    error_message = "var.labels wins over context.extra_tags."
  }

  assert {
    condition     = output.labels.team == "core-team"
    error_message = "context.extra_tags is merged."
  }
}

run "test_storage_trigger_grants_gcs_publisher" {
  command = plan

  variables {
    eventarc_triggers = {
      uploads = { event_type = "google.cloud.storage.object.v1.finalized", bucket = "my-bucket" }
    }
  }

  assert {
    condition     = length(google_project_iam_member.gcs_pubsub_publisher) == 1 && google_project_iam_member.gcs_pubsub_publisher[0].role == "roles/pubsub.publisher"
    error_message = "Storage triggers grant pubsub.publisher to the Cloud Storage service agent."
  }
}

run "test_pubsub_trigger_no_gcs_publisher" {
  command = plan

  variables {
    eventarc_triggers = {
      events = { event_type = "google.cloud.pubsub.topic.v1.messagePublished", pubsub_topic = "projects/example-project/topics/t" }
    }
  }

  assert {
    condition     = length(google_project_iam_member.gcs_pubsub_publisher) == 0
    error_message = "No GCS publisher grant without storage triggers."
  }
}

run "test_bucket_only_for_storage_events" {
  command = plan

  variables {
    eventarc_triggers = {
      events = { event_type = "google.cloud.pubsub.topic.v1.messagePublished", bucket = "b" }
    }
  }

  expect_failures = [var.eventarc_triggers]
}

run "test_short_name_rejected_for_created_sa" {
  command = plan

  variables {
    name = "app"
  }

  expect_failures = [output.service_account_email]
}
