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
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "state_bucket" {
  description = "S3 bucket holding remote state (to read the foundation layer)."
  type        = string
}

variable "cluster_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.32"
}

variable "node_pools" {
  description = "EKS Auto Mode built-in node pools to enable."
  type        = list(string)
  default     = ["general-purpose", "system"]
}

variable "cluster_endpoint_public_access" {
  description = "Expose the public API endpoint (needed for local apply / kubectl). Lock down CIDRs in prod."
  type        = bool
  default     = true
}
