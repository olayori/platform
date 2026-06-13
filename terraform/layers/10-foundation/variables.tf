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

variable "vpc_cidr" {
  description = "CIDR block for the platform VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cheaper, fine for one non-prod env). Set false for one-per-AZ HA."
  type        = bool
  default     = true
}

variable "service_names" {
  description = "Services that each get a private ECR repository."
  type        = list(string)
  default     = ["service-a", "service-b", "frontend"]
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to assume the CI role via OIDC."
  type        = string
  default     = "adowol/platform"
}
