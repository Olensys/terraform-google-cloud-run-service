output "id" {
  description = "Fully qualified id of the Cloud Run service. Null when create is false."
  value       = var.create ? google_cloud_run_v2_service.this[0].id : null
}

output "name" {
  description = "Name of the Cloud Run service. Null when create is false."
  value       = var.create ? google_cloud_run_v2_service.this[0].name : null
}

output "self_link" {
  description = "URI of the service (same as uri). Null when create is false."
  value       = var.create ? google_cloud_run_v2_service.this[0].uri : null
}

output "uri" {
  description = "HTTPS URI of the service. Null when create is false. Fails the plan when allUsers or allAuthenticatedUsers is an invoker without INGRESS_TRAFFIC_ALL, or when a name is in both env and secret_env."
  value       = var.create ? google_cloud_run_v2_service.this[0].uri : null

  precondition {
    condition     = var.ingress == "INGRESS_TRAFFIC_ALL" || !anytrue([for m in var.invoker_members : contains(["allUsers", "allAuthenticatedUsers"], m)])
    error_message = "invoker_members may contain allUsers or allAuthenticatedUsers only when ingress is INGRESS_TRAFFIC_ALL."
  }

  precondition {
    condition     = length(setintersection(toset(keys(var.env)), toset(keys(var.secret_env)))) == 0
    error_message = "A variable name must not appear in both env and secret_env."
  }
}

output "service_account_email" {
  description = "Runtime service account email (created or supplied). Null when create is false."
  value       = local.sa_email

  precondition {
    condition     = !local.create_sa || length(local.sa_account_id) >= 6
    error_message = "A module-created service account needs name to give an account id of at least 6 characters; use a longer name or set service_account_email."
  }
}

output "labels" {
  description = "Labels applied to every labelled resource, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.labels : null
}

output "ingress_setting" {
  description = "Effective ingress setting of the service. Null when create is false."
  value       = var.create ? var.ingress : null
}

output "secret_ids" {
  description = "Full names (projects/<project>/secrets/<id>) of the secrets the runtime service account can access. Null when create is false."
  value       = var.create ? sort(tolist(local.secret_names)) : null
}
