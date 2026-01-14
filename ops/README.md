# BL Ethos Infrastructure Operations

This directory contains infrastructure-as-code (IaC) for managing the BL Ethos Knapsack infrastructure on AWS EKS. The infrastructure is managed using OpenTofu (Terraform-compatible) and provisions Kubernetes resources on an existing EKS cluster.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Access](#getting-access)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Terraform Workflow](#terraform-workflow)
- [Making Changes](#making-changes)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Additional Resources](#additional-resources)

## Overview

This infrastructure configuration manages Kubernetes resources on the **r2-bl-ethos** EKS cluster in the **eu-west-1** AWS region. It provisions:

- **Infrastructure Components**: AWS Load Balancer Controller, Ingress NGINX, cert-manager
- **Application Dependencies**: PostgreSQL databases, Apache Solr, Fedora Repository
- **Storage**: EFS and EBS storage classes
- **Security**: IAM roles, service accounts, Kubernetes secrets

**Important**: This Terraform configuration does **not** create the EKS cluster itself. The cluster must already exist and be accessible.

## Prerequisites

Before working with this infrastructure, ensure you have:

1. **OpenTofu or Terraform** (v1.4.x or compatible)
   - Install via [tfswitch](https://github.com/warrensbox/terraform-switcher) (recommended) or direct download
   - Or install OpenTofu directly: `brew install opentofu/tap/opentofu`
2. **SOPS** (Mozilla Secrets Operations) - Required for encrypting/decrypting secrets
   - Install: `brew install sops`
   - Or download from [GitHub](https://github.com/mozilla/sops/releases)
3. **AWS CLI** installed and configured with appropriate credentials
4. **kubectl** installed and configured to access the EKS cluster
5. **Helm** (v3.x) installed
6. **Access to**:
   - AWS account with permissions for IAM, EKS, and related resources
   - Kubernetes cluster (`r2-bl-ethos`)
   - Backend PostgreSQL database credentials (for Terraform state)
   - **AWS KMS key access (for SOPS encryption/decryption)** - See [Getting Access](#getting-access) section below

## Getting Access

**⚠️ Important**: Before you can work with this infrastructure, you need several types of access. If you're a new developer, contact the infrastructure team to request access.

### Required Access

1. **AWS Account Access**
   - AWS account with permissions for IAM, EKS, and related resources
   - Contact: Infrastructure team
   - Verify: `aws sts get-caller-identity` should return your identity

2. **EKS Cluster Access**
   - Access to the `r2-bl-ethos` cluster in `eu-west-1` region
   - Contact: Infrastructure team or cluster administrator
   - Verify: `aws eks describe-cluster --name r2-bl-ethos --region eu-west-1` should succeed

3. **SOPS Key Setup (Required for Decryption)**
   - **YES, you need a SOPS key** - This is required to decrypt encrypted secret files
   - The encrypted files (`.backend.enc`, `kube_config.enc.yml`, `k8s/*-values.enc.yaml`) use SOPS encryption
   - You need to download the SOPS key from 1Password and add it to your keychain
   - See [Setting Up SOPS Key](#setting-up-sops-key) section below for detailed instructions

4. **PostgreSQL Backend Credentials**
   - Credentials for the Terraform state backend PostgreSQL database
   - These are stored in the encrypted `.backend.enc` file
   - Once you have SOPS key access and decrypt the file, the credentials will be in `.backend`
   - Contact: Infrastructure team if you need separate database access

### Setting Up SOPS Key

Before you can decrypt secrets, you need to download the SOPS key from 1Password and add it to your keychain.

1. **Download the SOPS Key from 1Password**
   - Open the SOPS key in 1Password: [SOPS Key](https://start.1password.com/open/i?a=KGDIV7IWMFDTVIQ5QGJYAWQ2KA&v=epvtqtbrtxmvra2m42mrlwzifi&i=zgkro5evber43o7crfat6xgvq4&h=my.1password.com)
   - Download the key file to your local machine
   - Note the location where you saved it (e.g., `~/Downloads/sops-key.asc`)

2. **Get the Passphrase from 1Password**
   - Open the SOPS key passphrase in 1Password: [SOPS Key Passphrase](https://start.1password.com/open/i?a=KGDIV7IWMFDTVIQ5QGJYAWQ2KA&v=epvtqtbrtxmvra2m42mrlwzifi&i=sompooyiakc2ipaw4maqyelcyi&h=my.1password.com)
   - Copy the passphrase (you'll need it in the next step)

3. **Import the Key and Add to Keychain**
   ```bash
   # Import the key (replace ~/Downloads/sops-key.asc with your actual path)
   gpg --import ~/Downloads/sops-key.asc

   # You'll be prompted for the passphrase - paste it from 1Password
   # After entering the passphrase, the key will be imported

   # Find your key ID (look for the line that says "pub" and note the key ID)
   # The key ID is the long string after the key type (e.g., "rsa4096")
   gpg --list-keys

   # Example output:
   # pub   rsa4096 2024-01-15 [SC]
   #       1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T
   # uid           [ultimate] Your Name <your.email@example.com>
   #
   # In this example, the key ID is: 1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T

   # Add to keychain (replace KEY_ID with the actual key ID from above)
   # On macOS, this integrates with the system keychain
   gpg --edit-key KEY_ID
   # In the GPG prompt, type: trust
   # Then: 5 (for "I trust ultimately")
   # Then: quit
   ```

4. **Configure SOPS to Use Your Key**

   After importing the key, you need to tell SOPS which key to use by updating the `.sops.yaml` configuration file:

   ```bash
   # Navigate to the provision directory
   cd ops/provision

   # Edit the .sops.yaml file (replace YOUR_PGP_KEY_ID with your actual key ID)
   # You can use any text editor:
   vim .sops.yaml
   # or
   nano .sops.yaml
   # or
   code .sops.yaml
   ```

   In the `.sops.yaml` file, replace `YOUR_PGP_KEY_ID` with your actual PGP key ID (the long string you found in step 3).

   The file should look like this (with your actual key ID):
   ```yaml
   creation_rules:
     - pgp: >-
         1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T
   ```

   **Note**: If multiple team members need to encrypt/decrypt files, you can add multiple key IDs separated by commas:
   ```yaml
   creation_rules:
     - pgp: >-
         1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T,
         2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T1A
   ```

5. **Verify SOPS Key Setup**
   ```bash
   # Test that SOPS can encrypt/decrypt files
   cd ops/provision

   # First, verify .sops.yaml is configured correctly
   # Check that it contains your key ID (not "YOUR_PGP_KEY_ID")
   grep -v "YOUR_PGP_KEY_ID" .sops.yaml > /dev/null && echo ".sops.yaml configured" || echo "WARNING: .sops.yaml still contains placeholder - update with your key ID"

   # Test decryption (if encrypted files exist)
   if [ -f .backend.enc ]; then
     sops --decrypt .backend.enc > /dev/null && echo "SOPS decryption successful!" || echo "SOPS decryption failed - check key import, passphrase, and .sops.yaml configuration"
   fi

   # Test encryption (create a test file)
   echo "test" > /tmp/sops-test.txt
   sops --encrypt /tmp/sops-test.txt > /tmp/sops-test.enc.txt && echo "SOPS encryption successful!" || echo "SOPS encryption failed - check .sops.yaml configuration"
   rm /tmp/sops-test.txt /tmp/sops-test.enc.txt
   ```

**Note**: If you're prompted for the passphrase each time you decrypt, the key may not be properly added to your keychain. Make sure you completed the trust step above.

### Verifying Your Access

After receiving access and setting up your SOPS key, verify everything works:

```bash
# 1. Verify AWS credentials
aws sts get-caller-identity

# 2. Verify EKS cluster access
aws eks describe-cluster --name r2-bl-ethos --region eu-west-1

# 3. Verify SOPS key is set up (this will fail if you don't have the key imported)
cd ops/provision
sops --decrypt .backend.enc > /dev/null && echo "SOPS key verified" || echo "SOPS key setup failed - see Setting Up SOPS Key section"

# 4. Decrypt all secrets (from repository root)
cd ../..
bin/decrypt-secrets

# 5. Verify Kubernetes access (after decrypting)
kubectl --kubeconfig=ops/provision/kube_config.yml get nodes
```

### Troubleshooting Access Issues

**If `bin/decrypt-secrets` fails with SOPS errors:**
- Error: `Error decrypting key: failed to get the data key required to decrypt the SOPS file`
- **Solution**: You haven't set up your SOPS key yet. Follow the [Setting Up SOPS Key](#setting-up-sops-key) section above to download the key from 1Password and import it.

- Error: `gpg: decryption failed: No secret key`
- **Solution**: The SOPS key isn't imported in your GPG keyring. Run `gpg --import` with the key file from 1Password.

- Error: `config file not found and no keys provided through command line options`
- **Solution**: The `.sops.yaml` file is missing or not configured. Make sure you've:
  1. Created/updated `ops/provision/.sops.yaml` with your PGP key ID
  2. Replaced `YOUR_PGP_KEY_ID` with your actual key ID from `gpg --list-keys`
  3. The file is in the `ops/provision/` directory

- Error: Prompted for passphrase repeatedly
- **Solution**: The key may not be trusted or added to your keychain. Run `gpg --edit-key KEY_ID` and set trust level to "ultimate" (option 5).

- Error: `sops metadata not found` when trying to decrypt
- **Solution**: The file wasn't encrypted with SOPS, or was encrypted incorrectly. Make sure you use `bin/encrypt-secrets` to encrypt files, and that `.sops.yaml` is properly configured before encrypting.

**If AWS CLI commands fail:**
- Error: `Unable to locate credentials`
- **Solution**: Configure AWS credentials using `aws configure` or set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

**If EKS cluster access fails:**
- Error: `An error occurred (ResourceNotFoundException)`
- **Solution**: Verify you have access to the `r2-bl-ethos` cluster and the `eu-west-1` region. Contact the infrastructure team if the cluster doesn't exist or you don't have access.

## Quick Start

### 1. Install Required Tools

**Install OpenTofu/Terraform**:

```bash
brew install opentofu/tap/opentofu
```

**Note**: Pay attention to the output. Additional steps may be required (e.g., updating your `$PATH`).

**Install SOPS** (if not already installed):

```bash
brew install sops
```

Verify installations:
```bash
terraform version
# or
tofu version
sops --version
```

### 2. Navigate to Provision Directory

```bash
cd ops/provision
```

### 3. Set Up SOPS Key

**⚠️ Prerequisite**: Before decrypting secrets, you must set up your SOPS key from 1Password. See the [Setting Up SOPS Key](#setting-up-sops-key) section in Getting Access above.

### 4. Decrypt Backend Secrets

**⚠️ Prerequisite**: Ensure you have completed the SOPS key setup (see step 3 above). Without the SOPS key, this step will fail.

The Terraform backend configuration and other secret files are encrypted. Decrypt them first:

```bash
# From repository root
bin/decrypt-secrets
```

This decrypts all encrypted secret files in `ops/provision/`:
- `.backend.enc` → `.backend` (Terraform backend configuration)
- `kube_config.enc.yml` → `kube_config.yml` (Kubernetes config)
- `k8s/*-values.enc.yaml` → `k8s/*-values.yaml` (Helm values with secrets)
- `.env.*.enc` → `.env.*` (Environment files if present)

**If decryption fails**: You likely haven't set up your SOPS key yet. See the [Setting Up SOPS Key](#setting-up-sops-key) section above.

**Note**: After making changes to these files, remember to re-encrypt them using `bin/encrypt-secrets` (see [Encrypting Secrets After Changes](#encrypting-secrets-after-changes)).

### 5. Verify Access

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify EKS cluster exists
aws eks describe-cluster --name r2-bl-ethos --region eu-west-1

# Check Kubernetes access (if kube_config.yml exists)
kubectl --kubeconfig=kube_config.yml get nodes
```

If `kube_config.yml` is missing or incorrect, generate it:

```bash
aws eks update-kubeconfig --name r2-bl-ethos --region eu-west-1 --kubeconfig kube_config.yml
```

### 6. Initialize Terraform

```bash
terraform init -backend-config=.backend
```

Alternatively, you can run:

```bash
terraform init
```

This will prompt you for a PostgreSQL URL, which can be found in `.backend` after running `bin/decrypt-secrets`.

**What this does**:
- Downloads required providers (AWS, Kubernetes, Helm, kubectl, Rancher)
- Configures PostgreSQL backend for state storage
- Creates `.terraform` directory with provider plugins

**Expected output**:
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

## Directory Structure

```
ops/
├── README.md                          # This file
├── provision/                         # Terraform configuration directory
│   ├── main.tf                        # Main Terraform configuration
│   ├── .terraform.lock.hcl           # Provider version lock file
│   ├── .backend                      # Backend configuration (encrypted, gitignored)
│   ├── kube_config.yml               # Kubernetes config for providers
│   ├── efs_name                      # EFS filesystem ID
│   ├── aws-load-balancer-controller-policy.json  # IAM policy document
│   └── k8s/                          # Kubernetes manifests and Helm values
│       ├── ingress-nginx-values.yaml
│       ├── postgresql-values.yaml
│       ├── postgresql-17-production-values.yaml
│       ├── solr-values.yaml
│       ├── fcrepos3-values.yaml
│       ├── cloudflare-api-token-secret.yaml
│       ├── prod_issuer.yaml
│       ├── prod-issuer-dns-values.yaml
│       └── github-registry-secret-values.yaml
├── default-deploy.tmpl.yaml          # Default deployment template
├── production-deploy.tmpl.yaml       # Production deployment template
└── staging-deploy.tmpl.yaml          # Staging deployment template
```

## Terraform Workflow

### Terraform Plan

**Always run plan before apply** to preview changes:

```bash
terraform plan
```

This shows what Terraform will create, modify, or destroy without making any changes.

**Reading the output**:
- `+` = Resource will be created
- `~` = Resource will be modified
- `-` = Resource will be destroyed
- `-/+` = Resource will be replaced (destroyed and recreated)

**Best practices**:
- Review the plan carefully, especially for destructive changes
- Save plan output for review: `terraform plan -out=tfplan`
- Use `-target` to plan specific resources: `terraform plan -target=helm_release.postgresql`

**Common issues**:
- **State lock**: Another user is running Terraform. Wait or contact them.
- **Provider errors**: Run `terraform init -upgrade` to update providers
- **Missing variables**: Check for required variables in configuration

### Terraform Apply

Once you've reviewed the plan and are confident with the changes:

```bash
terraform apply
```

This will:
1. Show the plan again (same as `terraform plan`)
2. Prompt for confirmation (type `yes` to proceed)
3. Create/modify/destroy resources in dependency order
4. Update the state file

**Non-interactive mode** (use with caution):
```bash
terraform apply -auto-approve
```

**Applying a saved plan**:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

**Resource creation order**:
1. IAM resources (policy, role)
2. Service accounts
3. AWS Load Balancer Controller
4. Ingress NGINX
5. cert-manager
6. Certificate issuers
7. Storage classes
8. Databases (PostgreSQL)
9. Applications (Fedora, Solr)

**Best practices**:
- Never skip the plan step
- Apply during maintenance windows (some changes cause brief interruptions)
- Monitor progress and watch for errors
- Verify resources after apply

### Terraform Destroy

**⚠️ WARNING**: This will delete **all** resources, including databases with data!

```bash
terraform destroy
```

**When to use**:
- Cleaning up test environments
- Complete infrastructure teardown
- Disaster recovery scenarios

**Partial destroy** (destroy specific resources):
```bash
terraform destroy -target=helm_release.postgresql
```

**Best practices**:
- Backup databases and important data first
- Double-check you're in the right environment
- Use with extreme caution in production

### Other Useful Commands

```bash
# Validate configuration syntax
terraform validate

# Format Terraform code
terraform fmt

# Refresh state (sync with actual resources)
terraform refresh

# List resources in state
terraform state list

# Show resource details
terraform state show <resource-type>.<name>

# Import existing resource
terraform import <resource-type>.<name> <resource-id>

# Remove from state (without destroying)
terraform state rm <resource-type>.<name>
```

## Making Changes

### Workflow for Infrastructure Changes

1. **Create a feature branch**
   ```bash
   git checkout -b infrastructure/your-change-name
   ```

2. **Make your changes**
   - Edit `main.tf` or files in `k8s/` directory
   - Follow existing patterns and conventions

3. **Test locally**
   ```bash
   terraform init -upgrade  # Update providers if needed
   terraform validate       # Check syntax
   terraform plan           # Review changes
   ```

4. **Get code review**
   - Push branch and create pull request
   - Have team review the plan output
   - Discuss impact and timing

5. **Apply changes**
   - After approval, merge to main
   - Apply in appropriate environment
   - Monitor for issues

### Common Change Scenarios

#### Updating Helm Chart Versions

1. Edit the `version` field in the Helm release resource in `main.tf`
2. Run `terraform plan` to see the update
3. Review Helm chart release notes for breaking changes
4. Apply during maintenance window if needed

#### Modifying Resource Configuration

1. Edit the resource block in `main.tf`
2. Or edit values files in `k8s/` directory
3. Run `terraform plan` to preview changes
4. Apply changes

#### Adding a New Helm Release

1. Add resource to `main.tf`:
   ```hcl
   resource "helm_release" "new_service" {
     name       = "new-service"
     namespace  = "default"
     repository = "https://charts.example.com"
     chart      = "service-chart"
     version    = "1.0.0"
     values     = [file("k8s/new-service-values.yaml")]
   }
   ```

2. Create values file in `k8s/` directory
3. Run `terraform plan` to verify
4. Apply changes

#### Adding Environment Variables or Secrets

**For Kubernetes Secrets**: Create or update YAML in `k8s/` directory

**For Helm values**: Add to values files

**Security Note**: Never commit plain-text secrets. Use:
- Kubernetes Secrets (referenced in YAML)
- AWS Secrets Manager
- Encrypted files (decrypted at runtime)

## Troubleshooting

### State Lock Errors

**Symptom**:
```
Error: Error acquiring the state lock
```

**Solutions**:
1. Wait if someone else is running Terraform
2. Check for stale locks
3. Force unlock (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```

### Provider Authentication Errors

**AWS Provider**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Configure if needed
aws configure
```

**Kubernetes Provider**:
```bash
# Update kubeconfig
aws eks update-kubeconfig --name r2-bl-ethos --region eu-west-1 --kubeconfig kube_config.yml

# Verify access
kubectl --kubeconfig=kube_config.yml get nodes
```

### Helm Release Failures

**Check Helm status**:
```bash
helm status <release-name> -n <namespace> --kubeconfig kube_config.yml
helm get manifest <release-name> -n <namespace> --kubeconfig kube_config.yml
```

**Common causes**:
- Invalid Helm chart version
- YAML syntax errors in values files
- Missing namespace (ensure `create_namespace = true` or namespace exists)
- Dependency resources not ready

### Backend Connection Issues

**Symptom**:
```
Error: Failed to get existing workspaces: dial tcp: connection refused
```

**Solutions**:
1. Verify `.backend` file exists and is decrypted
2. Test PostgreSQL connection manually
3. Check network access to PostgreSQL server
4. Verify credentials in `.backend` file

### Resource Dependency Errors

**Symptom**:
```
Error: resource depends on resource that doesn't exist
```

**Solutions**:
1. Check `depends_on` in resource definitions
2. Apply dependencies first using `-target`:
   ```bash
   terraform apply -target=helm_release.postgresql
   terraform apply
   ```

### Timeout Errors

**Symptom**:
```
Error: context deadline exceeded
```

**Solutions**:
1. Some resources (like databases) take time to provision - be patient
2. Check resource status manually:
   ```bash
   kubectl --kubeconfig=kube_config.yml get pods -A
   ```
3. Retry if it was a temporary network issue

### Checking Resource Status

```bash
# Kubernetes resources
kubectl --kubeconfig=kube_config.yml get all -A

# Specific namespace
kubectl --kubeconfig=kube_config.yml get all -n default

# Pod logs
kubectl --kubeconfig=kube_config.yml logs -n <namespace> <pod-name>

# Helm releases
helm list -A --kubeconfig kube_config.yml

# Terraform state
terraform state list
terraform state show <resource-type>.<name>
```

## Security Considerations

### Secrets Management

**Current State**: Some secrets are hardcoded in configuration files. This is a known issue.

**Secrets that need attention**:
1. **S3 Credentials**: In `k8s/fcrepos3-values.yaml`
   - Should be moved to Kubernetes Secrets or AWS Secrets Manager
2. **PostgreSQL Passwords**: In `k8s/postgresql-values.yaml`
   - Should be moved to Kubernetes Secrets
3. **Cloudflare API Token**: In `k8s/cloudflare-api-token-secret.yaml`
   - Should be stored as Kubernetes Secret

**Files with Secrets** (gitignored, encrypted versions committed):
- `ops/provision/k8s/*-values.yaml` - Helm values files containing passwords and API keys
  - Encrypted versions: `k8s/*-values.enc.yaml` (committed to git)
- `ops/provision/k8s/cloudflare-api-token-secret.yaml` - Cloudflare API token
  - Encrypted version: `k8s/cloudflare-api-token-secret.enc.yaml` (committed to git)
- `ops/provision/.backend` - Terraform backend PostgreSQL credentials
  - Encrypted version: `.backend.enc` (committed to git)
- `ops/provision/kube_config.yml` - Kubernetes configuration
  - Encrypted version: `kube_config.enc.yml` (committed to git)

**Best Practices**:
- Never commit plain-text secrets to version control
- Always encrypt files before committing or sharing
- Use Kubernetes Secrets for sensitive data
- Consider AWS Secrets Manager for external secrets
- Rotate credentials regularly

### Encrypting Secrets After Changes

**Important**: The files listed above are gitignored because they contain secrets. The repository uses encrypted versions of these files (with `.enc` extension) that are safe to commit. After making changes to decrypted files, you must encrypt them before committing.

#### Using the Encryption Scripts

The repository includes scripts to encrypt and decrypt secrets using SOPS (Mozilla Secrets Operations).

**Prerequisites**:
- SOPS must be installed: `brew install sops` (or download from [GitHub](https://github.com/mozilla/sops/releases))
- **SOPS key must be set up** - See [Setting Up SOPS Key](#setting-up-sops-key) section in Getting Access if you haven't done this yet
- The SOPS key is stored in 1Password and must be imported into your GPG keyring
- **`.sops.yaml` must be configured** - This file in `ops/provision/` tells SOPS which PGP key to use (see step 4 in Setting Up SOPS Key)

**Workflow for Editing Secrets**:

1. **Decrypt files** (from repository root):
   ```bash
   bin/decrypt-secrets
   ```
   This decrypts all encrypted files:
   - `.backend.enc` → `.backend`
   - `kube_config.enc.yml` → `kube_config.yml`
   - `k8s/*-values.enc.yaml` → `k8s/*-values.yaml`
   - `.env.*.enc` → `.env.*`

2. **Edit the decrypted files**:
   ```bash
   # Edit files as needed
   vim ops/provision/k8s/postgresql-values.yaml
   vim ops/provision/.backend
   # etc.
   ```

3. **Encrypt files** (from repository root):
   ```bash
   bin/encrypt-secrets
   ```
   This encrypts all plain text secret files and creates `.enc` versions:
   - `.backend` → `.backend.enc`
   - `kube_config.yml` → `kube_config.enc.yml`
   - `k8s/*-values.yaml` → `k8s/*-values.enc.yaml`
   - `.env.*` → `.env.*.enc`

4. **Commit the encrypted files**:
   ```bash
   git add ops/provision/.backend.enc
   git add ops/provision/k8s/*-values.enc.yaml
   git add ops/provision/kube_config.enc.yml
   git commit -m "Update encrypted secrets"
   ```

**Important Notes**:
- **Never commit** the plain text files (they're gitignored)
- **Always commit** the `.enc` versions after encrypting
- The scripts automatically skip files that already have `.enc` in the name
- Encrypted files can be safely committed to version control - only users with KMS access can decrypt them

**File Naming Convention**:
- Plain text files: `.backend`, `kube_config.yml`, `postgresql-values.yaml`
- Encrypted files: `.backend.enc`, `kube_config.enc.yml`, `postgresql-values.enc.yaml`

**Troubleshooting**:
- If SOPS is not installed, install it: `brew install sops`
- If you get KMS access errors, verify your AWS credentials and KMS key permissions
- If files aren't being encrypted, check that they match the patterns in the script and aren't already encrypted

### File Security

**Never commit** (gitignored):
- `.backend` file (plain text - contains database credentials)
- `kube_config.yml` (plain text - contains cluster credentials)
- `k8s/*-values.yaml` (plain text - contains passwords and API keys)
- **`.tfstate` files** - Terraform state files (contain sensitive resource data, stored remotely in PostgreSQL backend instead)
- **`.tfstate.backup` files** - Backup state files
- **`.terraform/` directory** - Local provider cache (recreated by `terraform init`)
- Plain-text secrets in any form

**Why not commit state files?**
- State files contain sensitive information (resource IDs, outputs, potentially secrets)
- State is stored remotely in PostgreSQL (configured via `.backend` file)
- Local state files are environment-specific and change frequently
- The remote PostgreSQL backend provides centralized, secure state storage with locking

**Do commit**:
- `main.tf` and other `.tf` files
- `.terraform.lock.hcl`
- **`.sops.yaml`** - SOPS configuration file (contains PGP key IDs, not secrets - safe to commit)
- **Encrypted secret files** (`.enc` versions):
  - `.backend.enc`
  - `kube_config.enc.yml`
  - `k8s/*-values.enc.yaml`
- Helm values files without secrets (e.g., `ingress-nginx-values.yaml` if it has no secrets)
- Kubernetes manifests without secrets

### IAM and Access Control

- AWS Load Balancer Controller uses OIDC-based IAM roles (IRSA)
- Service accounts are annotated with IAM role ARNs
- Minimal permissions principle applied to IAM policies

## Key Resources

### Cluster Information
- **Cluster Name**: `r2-bl-ethos`
- **Region**: `eu-west-1`
- **VPC ID**: `vpc-0e75da99cc686b282`
- **EFS ID**: `fs-0b4e488025a97af55` (stored in `efs_name` file)

### Namespaces
- `default` - Main application and databases
- `ethos-knapsack-staging` - Staging environment
- `ethos-knapsack-production` - Production environment
- `fcrepo` - Fedora Repository (production)
- `fcrepo-staging` - Fedora Repository (staging)
- `ingress-nginx` - Ingress controller
- `cert-manager` - Certificate management
- `kube-system` - System components

### Helm Releases

| Name | Namespace | Chart Repository |
|------|-----------|------------------|
| `aws-load-balancer-controller` | `kube-system` | AWS EKS Charts |
| `ingress-nginx` | `ingress-nginx` | Kubernetes |
| `cert-manager` | `cert-manager` | Jetstack |
| `postgresql` | `default` | Bitnami |
| `postgresql-17` | `default` | Bitnami |
| `postgresql` | `fcrepo` | Bitnami |
| `postgresql` | `fcrepo-staging` | Bitnami |
| `fcrepo` | `fcrepo` | Samvera Labs |
| `fcrepo-staging` | `fcrepo-staging` | Samvera Labs |
| `solr` | `default` | Bitnami |

## Additional Resources

### Documentation
- **Infrastructure Architecture**: `docs/infrastructure-architecture.md` - Complete technical documentation
- **Infrastructure Management Training**: `docs/infrastructure-management-training.md` - Beginner-friendly guide

### External Resources
- [OpenTofu Documentation](https://opentofu.org/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [tfswitch](https://github.com/warrensbox/terraform-switcher) - Terraform version manager

### Getting Help

1. **Check logs**: Review Terraform output and Kubernetes logs
2. **Review documentation**: Check this README and docs in `docs/` directory
3. **Team members**: Contact infrastructure team
4. **State issues**: Check backend connectivity and locks

## Quick Command Reference

```bash
# Initialize
terraform init -backend-config=.backend

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy resources (⚠️ DANGEROUS)
terraform destroy

# Validate configuration
terraform validate

# Format code
terraform fmt

# Check Kubernetes access
kubectl --kubeconfig=kube_config.yml get nodes

# List Helm releases
helm list -A --kubeconfig kube_config.yml
```

---

**Last Updated**: See git history for this file
**Maintainers**: Infrastructure Team
