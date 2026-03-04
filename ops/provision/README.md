# BL Ethos — EKS infrastructure (ops/provision/)

This directory contains **all** Terraform/OpenTofu for the **r2-bl-ethos** EKS cluster: infrastructure (VPC, IAM, EKS, node group, addons), cluster-level workloads (LB controller, EFS StorageClass), and app workloads (cert-manager, PostgreSQL, Fedora, Solr, namespaces). Backend and SOPS secrets live here; run Terraform only from this directory.

## Table of Contents

- [Overview](#overview)
- [Key resources](#key-resources)
- [Prerequisites](#prerequisites)
- [Backend and state](#backend-and-state)
- [Quick start (import existing cluster)](#quick-start-import-existing-cluster)
- [Directory structure](#directory-structure)
- [State backup](#state-backup)
- [Workflow (plan / apply)](#workflow-plan--apply)
- [Helm-only releases (not in Terraform)](#helm-only-releases-not-in-terraform)

## Overview

- **This root (`ops/provision/`)**: Holds all Terraform for r2-bl-ethos (EKS backbone, cluster workloads, app workloads). Backend config (`.backend.enc` → `.backend`) and SOPS secrets live here; run `bin/decrypt-secrets` from repo root before init/apply.
- **Backend**: PostgreSQL RDS (`backend "pg"`). State is isolated by workspace (or by `schema_name` if you pass it at init).

**Important**: The EKS cluster is **imported** into this configuration (not created from scratch). Use the import flow in [docs/EKS_IMPORT.md](docs/EKS_IMPORT.md) the first time.

## Key resources

| Resource   | Value |
|-----------|--------|
| **Cluster** | `r2-bl-ethos` |
| **Region**  | `eu-west-1` |
| **VPC ID**  | `vpc-0e75da99cc686b282` (after import; managed here) |
| **EFS ID**  | `fs-0b4e488025a97af55` (set `efs_file_system_id` in tfvars for EFS StorageClass) |

External dependencies not managed in this root: S3 bucket `samvera-fcrepo-bl-ethos`, Cloudflare, Let's Encrypt.

### Optional: cluster config output

- **Cluster config output** (`enable_cluster_config_output`): When `true`, Terraform writes `cluster-config/clusters/<name>/config.yaml` with versions, sizing, and feature flags for tooling (e.g. `bin/sync-cluster-config`). For r2-bl-ethos it is `false`. S3 buckets are not managed by this Terraform; FCRepo uses the external bucket `samvera-fcrepo-bl-ethos`.

## Prerequisites

- **OpenTofu or Terraform** (v1.4.x or compatible)
- **AWS CLI** with a profile that can assume a role in the BL account (see [Local setup: AWS profile](#local-setup-aws-profile) below).
- **PostgreSQL RDS backend** credentials (stored in `ops/provision/.backend` after decrypting `.backend.enc`; use `sslmode=require` in conn_str for RDS)
- **SOPS** and SOPS key for decrypt/encrypt — key is in 1Password; see project docs for setup

For the **import** flow you also need: `jq`, and AWS credentials that can describe the EKS cluster and related resources in the BL account.

### Local setup: AWS profile

Use a named profile so Terraform and kubectl assume the correct role in the cluster’s account. Add to **`~/.aws/config`**:

```ini
[profile bl]
region = eu-west-1
role_arn = arn:aws:iam::822951369940:role/ScientistAccess
source_profile = default
```

Replace `default` with your base profile if you use SSO or another profile. Then run all commands with:

```bash
AWS_PROFILE=bl terraform plan -var-file=envs/r2-bl-ethos.tfvars
AWS_PROFILE=bl kubectl get nodes
```

Verify: `AWS_PROFILE=bl aws sts get-caller-identity` should show **Account: 822951369940** and **Arn: .../ScientistAccess**.

## Backend and state

- **Backend type**: PostgreSQL RDS (`backend "pg"`). The pg backend does **not** support a `key` argument; state is keyed by workspace name (or use a separate schema via `schema_name`).
- **Init**: Decrypt first, then init:
  ```bash
  bin/decrypt-secrets   # from repo root
  cd ops/provision
  terraform init -backend-config=.backend
  ```
  Optional: use a separate schema so this project's state doesn't share the default schema with other configs:
  `terraform init -backend-config=.backend -backend-config=schema_name=eks_r2_bl_ethos`
- **State locking**: Handled by the PostgreSQL backend.

## Quick start (import existing cluster)

1. **Decrypt secrets** (from repo root):
   ```bash
   # From repo root
   bin/decrypt-secrets
   ```

2. **Init** (from `ops/provision/`):
   ```bash
   cd ops/provision
   terraform init -backend-config=.backend
   ```

3. **Backup state** (recommended before any import or major change):
   ```bash
   ./scripts/backup-state.sh
   ```
   Writes to `ops/provision/state-backups/terraform.tfstate.YYYYMMDD-HHMMSS`.

4. **Workspace**:
   ```bash
   terraform workspace new r2-bl-ethos
   terraform workspace select r2-bl-ethos
   ```

5. **Discover IDs** (BL account, eu-west-1):
   ```bash
   AWS_PROFILE=bl ./scripts/discover-eks-ids.sh r2-bl-ethos eu-west-1
   ```

6. **Update tfvars**: Merge `scripts/import-tfvars-snippet-r2-bl-ethos.txt` into `envs/r2-bl-ethos.tfvars`. Set `k8s_version`, `assume_role_arn`, and optionally `efs_file_system_id` (e.g. `fs-0b4e488025a97af55`).

7. **Import**:
   ```bash
   AWS_PROFILE=bl ./scripts/import-eks-cluster.sh r2-bl-ethos
   ```

8. **Verify**:
   ```bash
   AWS_PROFILE=bl terraform plan -var-file=envs/r2-bl-ethos.tfvars
   ```

Full steps and troubleshooting: [docs/EKS_IMPORT.md](docs/EKS_IMPORT.md).

## Directory structure

```
ops/provision/
├── README.md                    # This file
├── backend.tf                   # PostgreSQL RDS backend (config in .backend)
├── providers.tf                # AWS, Kubernetes, Helm, kubectl
├── main.tf                      # EKS cluster
├── network.tf                   # VPC, subnets, NAT, route tables
├── iam.tf                       # Cluster and node IAM roles
├── nodegroups.tf               # Launch template, node group
├── addons.tf                   # EBS/EFS CSI, kube-proxy, OIDC
├── cluster_workloads.tf        # LB controller, EFS StorageClass
├── app_workloads.tf            # cert-manager, PostgreSQL, Fedora, Solr, namespaces, kubectl manifests
├── aws-load-balancer-controller-policy.json
├── envs/
│   └── r2-bl-ethos.tfvars
├── scripts/
│   ├── backup-state.sh         # Backup state before changes
│   ├── discover-eks-ids.sh     # Discover AWS IDs for import
│   └── import-eks-cluster.sh   # Run terraform import
├── docs/
│   └── EKS_IMPORT.md
├── k8s/                        # Helm values and manifests; decrypt with bin/decrypt-secrets
│   ├── postgresql-values.yaml  # (decrypted from .enc.yaml)
│   ├── fcrepos3-values.yaml, solr-values.yaml, etc.
│   ├── cloudflare-api-token-secret.yaml, prod_issuer.yaml, prod-issuer-dns-values.yaml
│   └── github-registry-secret-values.yaml
├── state-backups/              # Gitignored; backup-state.sh output
└── .gitignore
```

**Secrets**: `k8s/*-values.yaml` and `.backend`, `kube_config.yml` are gitignored; encrypted `.enc` versions are committed. Run `bin/decrypt-secrets` from repo root.

## State backup

Before major changes (e.g. first import, upgrades):

```bash
./scripts/backup-state.sh
```

This runs `terraform state pull` and writes to `state-backups/terraform.tfstate.YYYYMMDD-HHMMSS`. The directory `state-backups/` is gitignored.

**Alternative** (manual one-liner):

```bash
terraform state pull > state-backup-$(date +%Y%m%d).json
```

**Recovery**: To restore from a backup, use `terraform state push` (use with caution and prefer restoring via the backend’s own backup if available).

## Workflow (plan / apply)

After import is done and plan is clean:

```bash
cd ops/provision
terraform workspace select r2-bl-ethos
AWS_PROFILE=bl terraform plan -var-file=envs/r2-bl-ethos.tfvars
AWS_PROFILE=bl terraform apply -var-file=envs/r2-bl-ethos.tfvars
```

Always run **plan** before apply. Use `./scripts/backup-state.sh` before applying large or risky changes.

## Helm-only releases (not in Terraform)

These releases are **not** in Terraform; they are managed purely with **Helm**. Values files in `k8s/` are the source of truth; apply changes with `helm upgrade` (from `ops/provision/`, kubeconfig targeting r2-bl-ethos):

| Release        | Namespace | Values file                              |
|----------------|-----------|------------------------------------------|
| postgresql     | default   | `k8s/postgresql-values.yaml`              |
| postgresql-17  | default   | `k8s/postgresql-17-production-values.yaml` |
| solr           | default   | `k8s/solr-values.yaml`                   |

```bash
# From ops/provision/
helm upgrade postgresql -n default -f k8s/postgresql-values.yaml oci://registry-1.docker.io/bitnamicharts/postgresql
helm upgrade postgresql-17 -n default -f k8s/postgresql-17-production-values.yaml oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.7.27
helm upgrade solr -n default -f k8s/solr-values.yaml oci://registry-1.docker.io/bitnamicharts/solr
```

All other Helm releases (cert-manager, postgresql in fcrepo/fcrepo-staging, fcrepo, fcrepo-staging) are in Terraform and get values on `terraform apply`.

### One-time: remove from Terraform state

If these releases were previously in Terraform state, remove them so Terraform does not try to destroy them after the resource blocks were removed. Run from `ops/provision/` with workspace `r2-bl-ethos` selected:

```bash
terraform state rm 'helm_release.postgresql' 'helm_release.postgresql_17' 'helm_release.solr'
```

Then run `terraform plan` / `apply` as usual; the releases stay in the cluster and are managed only by Helm.

## Quick command reference

```bash
# Init (from ops/provision/)
terraform init -backend-config=.backend

# Backup state
./scripts/backup-state.sh

# Plan / apply (after workspace select r2-bl-ethos)
AWS_PROFILE=bl terraform plan -var-file=envs/r2-bl-ethos.tfvars
AWS_PROFILE=bl terraform apply -var-file=envs/r2-bl-ethos.tfvars

# List state
terraform state list

# Validate / format
terraform validate
terraform fmt
```

## Testing the setup (after move to ops/provision)

Use these checks to confirm paths and tools work:

1. **Secrets (from repo root)**
   ```bash
   bin/decrypt-secrets
   ```
   Should run without error and decrypt files under `ops/provision/` (and `ops/provision/k8s/`). If it says "ops/provision/ not found", the path in the script is wrong.

2. **Terraform init and validate (from ops/provision)**
   ```bash
   cd ops/provision
   terraform init -backend-config=.backend
   terraform workspace select r2-bl-ethos
   terraform validate
   ```
   Init should succeed (backend config from `.backend`); validate should report "Success".

3. **Terraform plan (read-only, no apply)**
   ```bash
   AWS_PROFILE=bl terraform plan -var-file=envs/r2-bl-ethos.tfvars
   ```
   Should connect to AWS and show plan (no need to apply). If profile or tfvars path is wrong, this will fail.

4. **State backup script**
   ```bash
   ./scripts/backup-state.sh
   ```
   Should write a file under `ops/provision/state-backups/`.

5. **Capture script (optional; needs kubectl + EKS access)**
   ```bash
   AWS_PROFILE=bl ./scripts/capture-cluster-state.sh r2-bl-ethos
   ```
   Should create a timestamped directory under `ops/provision/cluster-captures/` if your context and EKS auth are set up (see [docs/CAPTURE_BEFORE_RANCHER_REMOVAL.md](docs/CAPTURE_BEFORE_RANCHER_REMOVAL.md)).

6. **Runbook links**
   Open [runbooks/remove-r2-bl-ethos-from-rancher-checklist.md](../../runbooks/remove-r2-bl-ethos-from-rancher-checklist.md) and confirm links to `../ops/provision/docs/...` resolve.
