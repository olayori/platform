# Adowol EKS Platform

A single-environment, production-shaped EKS platform.
**Terraform** (layered) builds the cloud infrastructure and bootstraps **Argo CD**;
**Argo CD** (GitOps) then deploys all in-cluster addons and applications from this repo.

> Full design rationale: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

```
terraform/   →  infrastructure (applied locally): VPC, ECR, IAM/OIDC, KMS, EKS Auto Mode, Argo CD bootstrap
gitops/      →  in-cluster state (reconciled by Argo CD): addons + workloads
services/    →  application source: 2 Go microservices + a static frontend
.github/     →  CI (test/build) and CD (build→push→bump GitOps tag)
```

## What you get

- **EKS in Auto Mode** — AWS manages compute (Karpenter), load balancing, EBS CSI, node patching.
- **Layered Terraform** — `bootstrap → foundation → compute → addons`, each with isolated state.
- **GitOps** — Argo CD App-of-Apps + ApplicationSet; `automated` sync with prune + self-heal.
- **Addons** — cert-manager, metrics-server, kube-prometheus-stack (Prometheus/Grafana/Alertmanager).
- **Apps** — `service-a` (`/api/hello`), `service-b` (`/api/time`), `frontend` (calls both), behind one ALB.
- **Keyless CI** — GitHub Actions → AWS via OIDC; immutable git-SHA image tags; tag bumps committed back to GitOps.

---

## Prerequisites

`terraform >= 1.10`, `awscli` (configured creds), `kubectl`, `helm`, `docker`, `go 1.22+`, `node 20+`.

```bash
aws sts get-caller-identity   # confirm you're authenticated to the right account
```

---

## Provision (local apply)

### 0. Set your repo identity (one-time)

The GitHub OIDC trust and the GitOps repo URL default to `adowol/platform`. If your
repo differs, override them:

- Terraform: `terraform/layers/10-foundation` var `github_repo`, and
  `terraform/layers/30-addons` var `gitops_repo_url`.
- GitOps manifests: the `repoURL` fields in `gitops/bootstrap/*.yaml` and `gitops/addons/*.yaml`.

### 1. Bootstrap remote state (run once)

```bash
make bootstrap BUCKET=adowol-dev-tfstate-<your-account-id>
# then capture the backend config the other layers use:
cd terraform/bootstrap && terraform output -raw backend_hcl > ../backend.hcl && cd -
```

### 2. Apply the layers

```bash
make up          # foundation → compute → addons, in order
# or one at a time:
make foundation-apply
make compute-apply
make addons-apply
```

### 3. Connect & watch GitOps reconcile

```bash
make kubeconfig
kubectl get applications -n argocd     # root, addons, workloads, service-a/b, frontend...
make argocd-ui                         # https://localhost:8080  (user: admin)
make argocd-password
```

### 4. Get the app URL

```bash
make ingress-url     # ALB hostname; open http://<hostname>/
```

---

## Deploy app changes (CI/CD)

Configure these once in the GitHub repo:

| Kind | Name | Value |
|------|------|-------|
| Secret | `AWS_CI_ROLE_ARN` | `github_ci_role_arn` output from the foundation layer |

Then the flow is automatic:

1. Open a PR → **CI** runs `go test` / `npm test` and builds images (no push).
2. Merge to `main` → **Build & Deploy** pushes images to ECR (`sha-<commit>`), runs
   `kustomize edit set image` on the changed services, and commits the tag bump.
3. **Argo CD** sees the new tag in `gitops/` and rolls the deployment.

> **First-deploy note:** a fresh cluster has empty ECR repos, so `service-*`/`frontend`
> pods `ImagePullBackOff` until the first push to `main` builds and bumps a real image tag.
> This is expected — the GitOps desired state exists before the first image does.

---

## Local development

```bash
make test                              # all service tests

cd services/service-a && go run .      # http://localhost:8080/api/hello
cd services/service-b && go run .      # http://localhost:8080/api/time
cd services/frontend  && python3 -m http.server 8080 --directory src
```

---

## Tear down

```bash
make down        # destroys addons → compute → foundation (state bucket is left intact)
```

---

## Layout

| Path | Purpose |
|------|---------|
| `terraform/bootstrap` | S3 remote-state bucket (local state, run once) |
| `terraform/layers/10-foundation` | VPC, ECR, KMS, GitHub OIDC + CI role |
| `terraform/layers/20-compute` | EKS cluster (Auto Mode) + access entries |
| `terraform/layers/30-addons` | Installs Argo CD + applies the root App-of-Apps |
| `gitops/bootstrap` | AppProject + addons app-of-apps + workloads ApplicationSet (what Argo CD watches) |
| `gitops/addons` | cert-manager, metrics-server, kube-prometheus-stack Applications |
| `gitops/apps/manifests` | Kustomize bases for each workload |
| `services/*` | Application source + Dockerfiles + tests |
| `.github/workflows` | `ci`, `build-and-deploy`, `terraform-validate` |

See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** for the full picture and day-2 roadmap.
