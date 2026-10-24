# Changelog

## [1.1.1](https://github.com/Olensys/terraform-google-cloud-run-service/compare/v1.1.0...v1.1.1) (2026-10-24)


### Bug Fixes

* run integration on change and weekly instead of nightly ([181b50c](https://github.com/Olensys/terraform-google-cloud-run-service/commit/181b50c7d634535f1dfd5dfdd9659bfbe79ca8ca))

## 1.1.0

### Fixes

- normalise `context.extra_tags` keys and values to valid GCP label syntax (lowercase, invalid characters to `-`, 63 characters); `labels` still win

### Tests

- `test_tags_contract` covers a mixed-case tag key and a value with a space

### Docs

- README usage shows the naming module

### Behaviour changes

- `context.extra_tags` entries now appear as normalised labels (for example `Team = "Core Team"` becomes `team = "core-team"`). Callers that relied on unnormalised keys must read the normalised ones; values that previously failed GCP label validation now succeed.

## 1.0.1

### Fixes

- report short service account ids through the output precondition
- grant Cloud Storage service agent pubsub publisher for storage triggers

### Tests

- expect provider rejection of short service account id

## 1.0.0

- Cloud Run v2 service with a dedicated service account, Secret Manager backed environment, scaling, Direct VPC egress, internal-load-balancer ingress by default, invoker grants and optional Eventarc triggers.
