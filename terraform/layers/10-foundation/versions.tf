terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Partial backend config — bucket/region come from -backend-config=backend.hcl.
  backend "s3" {
    bucket       = "adowol-dev-tfstate"
    key          = "layers/10-foundation/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
