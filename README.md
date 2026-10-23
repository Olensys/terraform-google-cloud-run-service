# terraform-google-cloud-run-service

Cloud Run v2 service with a dedicated service account, secret-backed environment, scaling, VPC egress, internal ingress by default and optional Eventarc triggers

## Opinions

- Second-generation execution environment (`EXECUTION_ENVIRONMENT_GEN2`).
- Ingress defaults to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`.
- No public invoker: `allUsers` / `allAuthenticatedUsers` in `invoker_members` fail the plan unless `ingress` is `INGRESS_TRAFFIC_ALL`.
- Dedicated runtime service account (account id is the first 30 characters of `name`, so use at least 6) unless `service_account_email` is supplied.
- Secrets come from Secret Manager (`secret_env`, latest version); the runtime service account gets `secretAccessor` on each distinct secret. Short ids resolve in `project_id`; pass a full `projects/<project>/secrets/<id>` name for another project.
- Startup probe: TCP check on `port`.
- CPU throttling (`cpu_idle`) and startup CPU boost are on.
- Deletion protection is on when `context.environment` is `prod`.
- Cloud Storage triggers (`bucket` set) also grant `roles/pubsub.publisher` to the project's Cloud Storage service agent. The trigger location is `region`, which must match the bucket location (a multi-region bucket needs a trigger in the matching multi-region location).
- Eventarc triggers run as the runtime service account, which receives `roles/eventarc.eventReceiver` and `roles/run.invoker`.
- `context.extra_tags` keys and values are normalised to valid GCP label syntax (lowercase, `[^a-z0-9_-]` → `-`, 63 chars); `labels` are applied verbatim and win.

## Usage

```hcl
module "naming" {
  source  = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"
  context = var.context
}

module "this" {
  source = "git::https://github.com/Olensys/terraform-google-cloud-run-service.git?ref=v1.1.0"

  name       = module.naming.name
  project_id = "my-project"
  region     = "europe-west1"
  image      = "us-docker.pkg.dev/cloudrun/container/hello"
  context = {
    organization = "olensys"
    environment  = "dev"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }

  labels = module.naming.labels
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0, < 8.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0, < 8.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_cloud_run_v2_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.eventarc_invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_cloud_run_v2_service_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_eventarc_trigger.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/eventarc_trigger) | resource |
| [google_project_iam_member.eventarc_receiver](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gcs_pubsub_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret_iam_member.runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_project_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | Container image to run, for example us-docker.pkg.dev/cloudrun/container/hello. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Service name. Lowercase letters, digits and hyphens, starting with a letter, at most 49 characters. Also the base of the created service account id (first 30 characters, so use at least 6 when the module creates the service account). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that hosts the service. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the service and of its Eventarc triggers. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to plan nothing. | `bool` | `true` | no |
| <a name="input_env"></a> [env](#input\_env) | Plain environment variables, env name => value. | `map(string)` | `{}` | no |
| <a name="input_eventarc_triggers"></a> [eventarc\_triggers](#input\_eventarc\_triggers) | Eventarc triggers delivering to the service, keyed by trigger suffix. Storage event types require bucket; pubsub\_topic selects the Pub/Sub transport topic (full topic name). | <pre>map(object({<br/>    event_type   = string<br/>    bucket       = optional(string)<br/>    pubsub_topic = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | Ingress setting: INGRESS\_TRAFFIC\_ALL, INGRESS\_TRAFFIC\_INTERNAL\_ONLY or INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER. | `string` | `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` | no |
| <a name="input_invoker_members"></a> [invoker\_members](#input\_invoker\_members) | IAM members granted roles/run.invoker, for example serviceAccount:x@p.iam.gserviceaccount.com. allUsers and allAuthenticatedUsers are only accepted with ingress INGRESS\_TRAFFIC\_ALL. | `list(string)` | `[]` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels merged onto every labelled resource, applied last. | `map(string)` | `{}` | no |
| <a name="input_port"></a> [port](#input\_port) | Container port that receives requests. The startup probe checks this port. | `number` | `8080` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Container resource limits. | <pre>object({<br/>    cpu    = optional(string, "1")<br/>    memory = optional(string, "512Mi")<br/>  })</pre> | `{}` | no |
| <a name="input_scaling"></a> [scaling](#input\_scaling) | Instance scaling: minimum and maximum instances and requests per instance. | <pre>object({<br/>    min         = optional(number, 0)<br/>    max         = optional(number, 10)<br/>    concurrency = optional(number, 80)<br/>  })</pre> | `{}` | no |
| <a name="input_secret_env"></a> [secret\_env](#input\_secret\_env) | Secret-backed environment variables, env name => Secret Manager secret. A short id (same project, expanded to projects/<project\_id>/secrets/<id>) or a full projects/<project>/secrets/<id> name for a secret in another project. The latest version is mounted and the runtime service account receives secretAccessor. | `map(string)` | `{}` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Runtime service account email. Null makes the module create a dedicated service account. | `string` | `null` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Direct VPC egress. Null disables VPC access. egress is ALL\_TRAFFIC or PRIVATE\_RANGES\_ONLY. | <pre>object({<br/>    network = string<br/>    subnet  = string<br/>    egress  = optional(string, "PRIVATE_RANGES_ONLY")<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Fully qualified id of the Cloud Run service. Null when create is false. |
| <a name="output_ingress_setting"></a> [ingress\_setting](#output\_ingress\_setting) | Effective ingress setting of the service. Null when create is false. |
| <a name="output_labels"></a> [labels](#output\_labels) | Labels applied to every labelled resource, with context.extra\_tags merged in. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Name of the Cloud Run service. Null when create is false. |
| <a name="output_secret_ids"></a> [secret\_ids](#output\_secret\_ids) | Full names (projects/<project>/secrets/<id>) of the secrets the runtime service account can access. Null when create is false. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | URI of the service (same as uri). Null when create is false. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Runtime service account email (created or supplied). Null when create is false. |
| <a name="output_uri"></a> [uri](#output\_uri) | HTTPS URI of the service. Null when create is false. Fails the plan when allUsers or allAuthenticatedUsers is an invoker without INGRESS\_TRAFFIC\_ALL, or when a name is in both env and secret\_env. |
<!-- END_TF_DOCS -->
