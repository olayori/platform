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

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart to install."
  type        = string
  default     = "7.7.7"
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the git repo Argo CD watches for manifests."
  type        = string
  default     = "https://github.com/olayori/platform.git"
}

variable "gitops_target_revision" {
  description = "Git branch/tag/commit Argo CD tracks."
  type        = string
  default     = "master"
}

variable "gitops_path" {
  description = "Path within the repo that holds the Argo CD bootstrap manifests."
  type        = string
  default     = "gitops/bootstrap"
}
