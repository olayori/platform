terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Bootstrap uses LOCAL state on purpose: it creates the very S3 bucket
  # that every other layer uses as its backend (chicken-and-egg).
  # Commit the resulting terraform.tfstate, or keep it safe — it only
  # describes the state bucket itself.
}
