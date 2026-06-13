variable "region" {
  description = "AWS region for the platform."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "adowol"
}

variable "environment" {
  description = "Environment name (single environment for this platform)."
  type        = string
  default     = "dev"
}

variable "state_bucket_name" {
  description = <<-EOT
    Globally-unique S3 bucket name to hold remote Terraform state for all layers.
    Must be unique across all of AWS. Suggested: "adowol-dev-tfstate-<your-account-id>".
  EOT
  type        = string
}
