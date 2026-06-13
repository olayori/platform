terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  backend "s3" {
    key          = "layers/20-compute/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
