variable "name" {
  description = "Service name. Lowercase letters, digits and hyphens, starting with a letter, at most 49 characters. Also the base of the created service account id (first 30 characters, so use at least 6 when the module creates the service account)."
  type        = string
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.name)) && length(var.name) <= 49
    error_message = "name must match ^[a-z]([a-z0-9-]*[a-z0-9])?$ and be at most 49 characters."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "project_id" {
  description = "Project that hosts the service."
  type        = string
}

variable "create" {
  description = "Whether to create any resources. Set false to plan nothing."
  type        = bool
  default     = true
}

variable "region" {
  description = "Region of the service and of its Eventarc triggers."
  type        = string
}

variable "image" {
  description = "Container image to run, for example us-docker.pkg.dev/cloudrun/container/hello."
  type        = string
}

variable "port" {
  description = "Container port that receives requests. The startup probe checks this port."
  type        = number
  default     = 8080
  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "port must be between 1 and 65535."
  }
}

variable "env" {
  description = "Plain environment variables, env name => value."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Secret-backed environment variables, env name => Secret Manager secret. A short id (same project, expanded to projects/<project_id>/secrets/<id>) or a full projects/<project>/secrets/<id> name for a secret in another project. The latest version is mounted and the runtime service account receives secretAccessor."
  type        = map(string)
  default     = {}
}

variable "resources" {
  description = "Container resource limits."
  type = object({
    cpu    = optional(string, "1")
    memory = optional(string, "512Mi")
  })
  default = {}
}

variable "scaling" {
  description = "Instance scaling: minimum and maximum instances and requests per instance."
  type = object({
    min         = optional(number, 0)
    max         = optional(number, 10)
    concurrency = optional(number, 80)
  })
  default = {}
  validation {
    condition     = var.scaling.min >= 0 && var.scaling.max >= 1 && var.scaling.min <= var.scaling.max && var.scaling.concurrency >= 1 && var.scaling.concurrency <= 1000
    error_message = "scaling requires 0 <= min <= max, max >= 1 and 1 <= concurrency <= 1000."
  }
}

variable "vpc" {
  description = "Direct VPC egress. Null disables VPC access. egress is ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  type = object({
    network = string
    subnet  = string
    egress  = optional(string, "PRIVATE_RANGES_ONLY")
  })
  default = null
  validation {
    condition     = var.vpc == null || contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], try(var.vpc.egress, ""))
    error_message = "vpc.egress must be ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  }
}

variable "ingress" {
  description = "Ingress setting: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "ingress must be INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "invoker_members" {
  description = "IAM members granted roles/run.invoker, for example serviceAccount:x@p.iam.gserviceaccount.com. allUsers and allAuthenticatedUsers are only accepted with ingress INGRESS_TRAFFIC_ALL."
  type        = list(string)
  default     = []
}

variable "service_account_email" {
  description = "Runtime service account email. Null makes the module create a dedicated service account."
  type        = string
  default     = null
}

variable "eventarc_triggers" {
  description = "Eventarc triggers delivering to the service, keyed by trigger suffix. Storage event types require bucket; pubsub_topic selects the Pub/Sub transport topic (full topic name)."
  type = map(object({
    event_type   = string
    bucket       = optional(string)
    pubsub_topic = optional(string)
  }))
  default = {}
  validation {
    condition     = alltrue([for t in values(var.eventarc_triggers) : !startswith(t.event_type, "google.cloud.storage.") || t.bucket != null])
    error_message = "Storage event types (google.cloud.storage.*) require bucket."
  }
}

variable "labels" {
  description = "Labels merged onto every labelled resource, applied last."
  type        = map(string)
  default     = {}
}
