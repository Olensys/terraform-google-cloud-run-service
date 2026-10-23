terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
  }
}

variable "project_id" {
  description = "Project that hosts the service."
  type        = string
}

provider "google" {
  project = var.project_id
}

module "this" {
  source = "../../"

  name       = "example-app"
  project_id = var.project_id
  region     = "europe-west1"
  image      = "us-docker.pkg.dev/cloudrun/container/hello"
  port       = 8080
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
}

output "uri" {
  description = "URI of the service."
  value       = module.this.uri
}
