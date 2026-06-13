provider "aws" {
  region = var.region
}

# Read the compute layer's outputs (cluster endpoint, CA, name).
data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "adowol-dev-tfstate"
    key    = "layers/20-compute/terraform.tfstate"
    region = var.region
  }
}

locals {
  cluster_name     = data.terraform_remote_state.compute.outputs.cluster_name
  cluster_endpoint = data.terraform_remote_state.compute.outputs.cluster_endpoint
  cluster_ca       = data.terraform_remote_state.compute.outputs.cluster_certificate_authority_data
}

# Auth to the cluster using the AWS CLI exec plugin (always-fresh token).
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
  }
}

provider "kubectl" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_ca)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_ca)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
    }
  }
}

# ---------------------------------------------------------------------------
# Argo CD — the ONLY thing Terraform installs into the cluster.
# Everything else (addons + apps) is pulled from git by Argo CD.
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # Wait for the CRDs + server to be ready before we apply the root Application.
  wait    = true
  timeout = 900

  values = [yamlencode({
    global = {
      # Auto Mode places pods on managed nodes; nothing special needed.
    }
    configs = {
      params = {
        # The frontend ALB / port-forward terminates TLS; run server insecure
        # behind it to avoid double-TLS in this single-env setup.
        "server.insecure" = true
      }
    }
    # Keep the bundled controllers lean for a single environment.
    controller = {
      replicas = 1
    }
    server = {
      replicas = 1
    }
    repoServer = {
      replicas = 1
    }
    applicationSet = {
      replicas = 1
    }
  })]
}

# ---------------------------------------------------------------------------
# Root App-of-Apps — points Argo CD at this repo's gitops/ tree and hands off.
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = "argocd"
      finalizers = [
        "resources-finalizer.argocd.argoproj.io",
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = var.gitops_path
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })
}
