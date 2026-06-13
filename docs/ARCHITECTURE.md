# Adowol EKS Platform — Architecture

> A production-shaped, single-environment EKS platform built with **layered Terraform** for
> infrastructure and **Argo CD (GitOps)** for everything that runs *inside* the cluster.
> Terraform builds the cluster and bootstraps Argo CD; Argo CD takes over from there.

---

## 1. Goals & Principles

| Principle | How it shows up here |
|-----------|----------------------|
| **Separation of concerns** | Terraform owns cloud infra (VPC, EKS, IAM, ECR). Argo CD owns in-cluster state (addons + apps). The handoff point is a single Argo CD bootstrap. |
| **Layered infra** | Terraform is split into independent layers with their own state: `bootstrap → foundation → compute → addons`. Each layer reads the previous via remote state. Blast radius is contained. |
| **GitOps as the source of truth** | The desired state of the cluster lives in Git (`gitops/`). Argo CD continuously reconciles. No `kubectl apply` by humans. |
| **Least privilege** | GitHub Actions authenticates to AWS via **OIDC** (no long-lived keys). Workloads use **EKS Pod Identity / IRSA**. ECR is private. |
| **Managed > self-managed** | **EKS Auto Mode** manages compute (Karpenter), the AWS Load Balancer Controller, EBS CSI, CoreDNS scaling, and node lifecycle — so we don't. |
| **Reproducible & local-first** | All Terraform is applied locally (`make` targets). No CI cloud-apply, so credentials stay on the operator's machine. CI only builds/tests/pushes images and bumps GitOps tags. |

---

## 2. High-Level Diagram

```
                          ┌──────────────────────────────────────────────────────────┐
   Developer              │                        AWS Account                        │
   pushes code            │                                                            │
       │                  │   ┌────────────┐   ┌─────────────────────────────────┐    │
       ▼                  │   │    ECR     │   │            VPC (foundation)     │    │
 ┌────────────┐  build &  │   │  (private  │   │  3 AZ · public + private subnets│    │
 │   GitHub    │  push img │   │   repos)   │   │  NAT GW · VPC endpoints         │    │
 │   Actions   │──────────┼──▶│ service-a  │   │   ┌─────────────────────────┐   │    │
 │  (CI: test, │  (OIDC)   │   │ service-b  │   │   │   EKS Auto Mode cluster │   │    │
 │  build,     │           │   │ frontend   │   │   │   (compute layer)       │   │    │
 │  push, bump)│           │   └────────────┘   │   │                         │   │    │
 └─────┬──────┘            │                    │   │  ┌───────────────────┐  │   │    │
       │ commit new        │                    │   │  │     Argo CD       │  │   │    │
       │ image tag to      │                    │   │  │  (bootstrapped by │  │   │    │
       │ gitops/           │                    │   │  │   addons layer)   │  │   │    │
       ▼                   │                    │   │  └─────────┬─────────┘  │   │    │
 ┌────────────┐  watches   │                    │   │            │ reconciles │   │    │
 │   Git repo  │◀───────────┼────────────────────┼───┤            ▼            │   │    │
 │  gitops/    │  (Argo CD) │                    │   │  addons:  cert-manager, │   │    │
 │  (manifests)│            │                    │   │  metrics-server,        │   │    │
 └────────────┘            │                    │   │  kube-prometheus-stack  │   │    │
                           │                    │   │  apps:    service-a,    │   │    │
                           │                    │   │  service-b, frontend    │   │    │
                           │                    │   │            │            │   │    │
                           │                    │   │            ▼            │   │    │
                           │              ┌─────┴───┴── ALB (Auto Mode) ──────┴┐  │    │
                           │   Internet ─▶│  Ingress → frontend / service-a / b │  │    │
                           │              └─────────────────────────────────────┘  │    │
                           └──────────────────────────────────────────────────────────┘
```

---

## 3. Repository Layout

```
platform/
├── docs/
│   └── ARCHITECTURE.md          ← this document
│
├── terraform/                   ← INFRASTRUCTURE (applied locally)
│   ├── bootstrap/               # Layer 0: S3 state bucket + DynamoDB lock (local state)
│   ├── modules/                 # shared, reusable modules
│   └── layers/
│       ├── 10-foundation/       # Layer 1: VPC, ECR, KMS, GitHub OIDC provider + CI role
│       ├── 20-compute/          # Layer 2: EKS cluster in Auto Mode + access entries
│       └── 30-addons/           # Layer 3: install Argo CD (Helm) + apply the root App
│
├── gitops/                      ← IN-CLUSTER STATE (reconciled by Argo CD)
│   ├── bootstrap/
│   │   └── root-app.yaml         # App-of-Apps root (applied by Terraform layer 30)
│   ├── projects/
│   │   └── platform-project.yaml # Argo CD AppProject (RBAC + source/dest allowlist)
│   ├── addons/                   # platform addons as Argo CD Applications
│   │   ├── cert-manager.yaml
│   │   ├── metrics-server.yaml
│   │   └── kube-prometheus-stack.yaml
│   └── apps/                     # workloads
│       ├── applicationset.yaml   # ApplicationSet that generates one App per service
│       └── manifests/            # Kustomize bases (one dir per service)
│           ├── service-a/
│           ├── service-b/
│           └── frontend/
│
├── services/                    ← APPLICATION SOURCE CODE
│   ├── service-a/               # Go HTTP API ("greeter")  — /api/hello
│   ├── service-b/               # Go HTTP API ("time")     — /api/time
│   └── frontend/                # static SPA on nginx-unprivileged
│
├── .github/workflows/           ← CI/CD
│   ├── ci.yaml                  # PR + push: lint, test, build (no push)
│   ├── build-and-deploy.yaml    # master: build → push to ECR → bump gitops tag
│   └── terraform-validate.yaml  # PR: fmt + validate the terraform layers
│
├── Makefile                     # operator entrypoints (tf-*, build-*, bootstrap)
└── README.md                    # quickstart / runbook
```

**Why two top-level trees (`terraform/` vs `gitops/`)?** They have different lifecycles,
owners, and tools. Terraform changes are infrequent, privileged, and applied by an operator.
GitOps changes are frequent, low-privilege, and applied by a controller. Keeping them apart
makes ownership and CI scoping obvious — but they live in **one repo** for a single source of truth.

---

## 4. Terraform Layers

Each layer is a **separate root module with its own state file** in the shared S3 backend
(keyed by layer name). Downstream layers consume upstream outputs via
`terraform_remote_state`. This is the "infra-layers" model: you can plan/apply one layer
without touching the others, and a mistake in `addons` can never corrupt `foundation` state.

### Layer 0 — `bootstrap`
Creates the remote-state backend itself (an S3 bucket with versioning + encryption and a
DynamoDB table for state locking). Uses **local state** (chicken-and-egg: it creates the very
bucket the others use). Run **once**, then never again.

### Layer 1 — `10-foundation`
The durable, slow-changing base. Rarely destroyed.
- **VPC** (`terraform-aws-modules/vpc`): 3 AZs, public + private subnets, single NAT gateway
  (cost-optimized for one env), tagged for EKS/ELB subnet discovery.
- **VPC endpoints** to keep AWS-bound traffic off the NAT gateway: a free **S3 gateway
  endpoint** (carries ECR image-layer data — the bulk of egress) plus interface endpoints
  for `ecr.api`, `ecr.dkr`, `sts` (configurable via `interface_vpc_endpoints`).
- **ECR**: one private repo per service (`service-a`, `service-b`, `frontend`) with image
  scanning on push and a lifecycle policy to expire untagged images.
- **KMS** key for EKS secret envelope encryption.
- **GitHub OIDC provider** + an IAM role (`github-actions-ci`) scoped to this repo, allowing
  CI to push to ECR with **no static credentials**.

### Layer 2 — `20-compute`
- **EKS cluster in Auto Mode** (`terraform-aws-modules/eks`, `cluster_compute_config.enabled = true`,
  node pools `general-purpose` + `system`). Auto Mode means AWS runs Karpenter, the AWS Load
  Balancer Controller, EBS CSI, and node OS patching for us.
- **API authentication mode** with **access entries** (the modern replacement for `aws-auth`
  ConfigMap). The local operator and the CI role get cluster-admin / scoped access.
- KMS envelope encryption for secrets, control-plane logging to CloudWatch.

### Layer 3 — `30-addons`
The **handoff to GitOps**. Deliberately thin:
1. Installs **Argo CD** via its Helm chart (the only thing Terraform installs in-cluster).
2. Applies the **root App-of-Apps** (`gitops/bootstrap/root-app.yaml`) pointing Argo CD at
   this repo's `gitops/` tree.

After this layer, Terraform's job inside the cluster is done. Everything else (cert-manager,
monitoring, the three services) is pulled in by Argo CD from Git.

> **Why install Argo CD with Terraform and not Helm-by-hand?** So the bootstrap is declarative,
> versioned, and reproducible. But we install *only* Argo CD this way to avoid the trap of
> managing dozens of Helm releases in Terraform — that's Argo CD's job.

---

## 5. GitOps Model (Argo CD)

We use the **App-of-Apps** pattern plus an **ApplicationSet** for workloads.

```
root-app (applied by Terraform)
   │  watches gitops/  (recursively discovers child Applications)
   ├── projects/platform-project.yaml      → AppProject "platform"
   ├── addons/cert-manager.yaml             → Application (Helm)
   ├── addons/metrics-server.yaml           → Application (Helm)
   ├── addons/kube-prometheus-stack.yaml    → Application (Helm)
   └── apps/applicationset.yaml             → ApplicationSet
            ├── generates → service-a Application  (Kustomize)
            ├── generates → service-b Application  (Kustomize)
            └── generates → frontend  Application  (Kustomize)
```

- **Sync waves** order the rollout: addons (wave 0) before apps (wave 1), and within addons
  cert-manager/CRDs first.
- **`automated` sync** with `prune: true` and `selfHeal: true` — drift is corrected
  automatically and deleted manifests are removed from the cluster.
- The **ApplicationSet git-directory generator** means adding a new service is just adding a
  directory under `gitops/apps/manifests/` — no new Application YAML to hand-write.
- Workloads are described with **Kustomize** (plain, dependency-free, easy to diff). Addons are
  upstream **Helm charts** wrapped in Argo CD Applications so we get version-pinned, official charts.

### Why this is the source of truth
The image **tag** in each service's `kustomization.yaml` is the deployment contract. CI changes
that tag via a Git commit; Argo CD notices and rolls the Deployment. There is no imperative
deploy step anywhere.

---

## 6. Applications

| Service | Language / Runtime | Purpose | Endpoints | Image base |
|---------|--------------------|---------|-----------|------------|
| `service-a` | Go (stdlib only) | "greeter" API | `/api/hello`, `/healthz`, `/readyz` | distroless/static nonroot |
| `service-b` | Go (stdlib only) | "time" API | `/api/time`, `/healthz`, `/readyz` | distroless/static nonroot |
| `frontend` | Static HTML/JS/CSS | UI that calls A & B | `/` (SPA), `/healthz` | nginx-unprivileged |

All three:
- Listen on **:8080** and run as **non-root** (required by the platform's hardened defaults).
- Ship liveness (`/healthz`) and readiness (`/readyz`) probes.
- Are routed by a single **Ingress** (Auto Mode provisions an ALB):
  - `/` → `frontend`
  - `/api/hello` → `service-a`
  - `/api/time` → `service-b`

Kubernetes hardening applied to every workload: `runAsNonRoot`, `readOnlyRootFilesystem`,
dropped Linux capabilities, resource requests/limits, `PodDisruptionBudget`, and an
`HorizontalPodAutoscaler` driven by metrics-server.

---

## 7. CI/CD Flow

```
┌── ci.yaml (PR & push to any branch) ─────────────────────────────┐
│  detect changed services → go test / npm test → docker build     │
│  (build is a verification only; nothing is pushed)               │
└──────────────────────────────────────────────────────────────────┘

┌── build-and-deploy.yaml (push to master) ────────────────────────┐
│  1. assume CI role via OIDC (no static AWS keys)                 │
│  2. docker build + push to ECR, tagged with the git SHA          │
│  3. `kustomize edit set image` in gitops/apps/manifests/<svc>    │
│  4. commit + push the tag bump back to the repo                  │
│         │                                                         │
│         ▼                                                         │
│  Argo CD detects the new tag in Git → syncs → rolling update     │
└──────────────────────────────────────────────────────────────────┘

┌── terraform-validate.yaml (PR touching terraform/) ──────────────┐
│  terraform fmt -check + init -backend=false + validate per layer │
└──────────────────────────────────────────────────────────────────┘
```

**Image tags are immutable git SHAs**, never `latest` — so a deployment is always traceable to
an exact commit, and Argo CD always sees a real diff to sync.

**Why CI doesn't apply Terraform:** the requirement is local apply. CI has push-to-ECR rights
only; cluster-shaping stays with the operator. This keeps the privileged blast radius off CI.

---

## 8. Security Posture

- **No static cloud credentials in CI** — GitHub OIDC → short-lived STS.
- **Private ECR** with scan-on-push and untagged-image expiry.
- **EKS secrets** encrypted at rest with a dedicated KMS key.
- **Access entries** (not `aws-auth`) for cluster authz; CI role is scoped, not admin.
- **Hardened pods** — non-root, read-only rootfs, dropped caps, seccomp `RuntimeDefault`.
- **Network**: nodes in private subnets; only the ALB is internet-facing.
- **cert-manager** issues TLS; ready to wire to ACM/Let's Encrypt per domain.

---

## 9. Day-2 / What a real prod setup adds next

This repo is a complete, working skeleton. Natural extensions, called out honestly:

- **Multi-env**: promote the layer model to `envs/{dev,staging,prod}` with per-env tfvars and
  Argo CD ApplicationSet generators per cluster.
- **Secrets**: External Secrets Operator + AWS Secrets Manager (stubbed-in addon slot).
- **Observability**: kube-prometheus-stack is included; add Loki/Tempo + OTel for logs/traces.
- **Policy**: Kyverno or OPA Gatekeeper admission policies, plus image signing (cosign) verified at admission.
- **DNS/TLS**: external-dns + a real hosted zone and ACM cert on the Ingress.
- **Progressive delivery**: Argo Rollouts for canary/blue-green.
- **DR**: Velero backups of cluster state; state-bucket cross-region replication.

See the root `README.md` for the step-by-step apply/runbook.
```

