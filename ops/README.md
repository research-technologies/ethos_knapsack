# BL Ethos Infrastructure Operations

This directory contains infrastructure-as-code (IaC) for managing the BL Ethos Knapsack infrastructure on AWS EKS. The infrastructure is managed using OpenTofu (Terraform-compatible) and provisions Kubernetes resources on an existing EKS cluster.

## Table of Contents

- [Overview](#overview)
- [Architecture Overview](#architecture-overview)
- [Key Design Decisions](#key-design-decisions)
- [Infrastructure Resources](#infrastructure-resources)
- [Prerequisites](#prerequisites)
- [Getting Access](#getting-access)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Terraform Workflow](#terraform-workflow)
- [Making Changes](#making-changes)
- [Infrastructure Management Training](#infrastructure-management-training)
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

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Account (eu-west-1)                  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         EKS Cluster: r2-bl-ethos                      │  │
│  │  (Pre-existing, managed outside this Terraform)       │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │         Infrastructure Layer                  │  │
│  │  │  - AWS Load Balancer Controller               │  │
│  │  │  - Ingress NGINX                              │  │
│  │  │  - cert-manager                                │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │         Application Layer                      │  │
│  │  │  - PostgreSQL (multiple instances)            │  │
│  │  │  - Solr (with ZooKeeper)                      │  │
│  │  │  - Fedora Repository (fcrepo)                 │  │
│  │  │  - Application Namespaces                     │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │         Storage Layer                         │  │
│  │  │  - EFS (Elastic File System)                  │  │
│  │  │  - EBS (via Storage Classes)                  │  │
│  │  │  - S3 (for Fedora object storage)            │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         IAM Resources                                 │  │
│  │  - AWS Load Balancer Controller IAM Role             │  │
│  │  - OIDC Provider Integration                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         External Services                            │  │
│  │  - Cloudflare (DNS/SSL)                              │  │
│  │  - Let's Encrypt (SSL Certificates)                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Component Overview

**Infrastructure Components:**
- **AWS Load Balancer Controller**: Manages AWS Application/Network Load Balancers, integrated with EKS via OIDC
- **Ingress NGINX**: Provides HTTP/HTTPS ingress, uses AWS Network Load Balancer (NLB)
- **cert-manager**: Manages SSL/TLS certificates automatically via Let's Encrypt and Cloudflare DNS

**Application Components:**
- **PostgreSQL**: Multiple instances across namespaces (default, fcrepo, fcrepo-staging)
- **Apache Solr**: Search engine with ZooKeeper coordination
- **Fedora Repository**: Digital repository software (production and staging instances)

**Storage:**
- **EFS**: File system ID `fs-0b4e488025a97af55` (exposed as `efs-sc` storage class)
- **EBS**: Via `gp2` storage class for databases and persistent volumes
- **S3**: Bucket `samvera-fcrepo-bl-ethos` for Fedora object storage

### Key Design Decisions

1. **EKS Cluster Management**: Cluster is pre-existing and managed outside this Terraform
   - **Rationale**: Cluster lifecycle is managed separately, allowing this configuration to focus on application infrastructure
   - **Implication**: Cluster must exist before running Terraform; cluster updates don't affect this configuration

2. **Environment Separation**: Uses Kubernetes namespaces (`ethos-knapsack-staging`, `ethos-knapsack-production`, `fcrepo`, `fcrepo-staging`)
   - **Rationale**: Logical separation without separate clusters reduces operational overhead
   - **Implication**: All environments share the same cluster resources; namespace-level isolation

3. **State Management**: PostgreSQL backend for centralized state storage with locking
   - **Rationale**: Enables team collaboration with state locking, version history, and centralized storage
   - **Implication**: Requires PostgreSQL database access; state is not stored locally or in git
   - **Backend Configuration**: Stored in encrypted `.backend.enc` file (decrypted to `.backend`)

4. **Helm Chart Management**: Direct Helm releases in Terraform for better state management
   - **Rationale**: Terraform tracks Helm releases as resources, enabling drift detection and lifecycle management
   - **Implication**: Helm releases are managed declaratively; manual Helm operations may cause drift

5. **IAM Integration**: OIDC-based IAM roles for service accounts (IRSA) for secure AWS API access
   - **Rationale**: Eliminates need for long-lived AWS credentials in pods; uses short-lived tokens
   - **Implementation**: Service accounts annotated with IAM role ARNs; OIDC provider configured on EKS cluster
   - **Used by**: AWS Load Balancer Controller

6. **VPC Configuration**: Hardcoded VPC ID (`vpc-0e75da99cc686b282`) - managed separately
   - **Rationale**: VPC is shared infrastructure managed outside this repository
   - **Implication**: VPC changes require coordination with infrastructure team

7. **Storage Strategy**:
   - **EFS**: Shared file storage (read from `efs_name` file: `fs-0b4e488025a97af55`)
   - **EBS**: Block storage via default `gp2` storage class for databases
   - **Rationale**: EFS for shared access, EBS for database performance

8. **Certificate Management**: cert-manager with Let's Encrypt and Cloudflare DNS
   - **Rationale**: Automated certificate provisioning and renewal
   - **Implementation**: HTTP-01 challenge for Let's Encrypt, DNS-01 challenge via Cloudflare for production

9. **Secrets Management**: SOPS encryption for sensitive files
   - **Rationale**: Allows committing encrypted secrets to git while maintaining security
   - **Implementation**: GPG key-based encryption; keys managed in 1Password

### State Management Approach

#### Backend Configuration

**Backend Type**: PostgreSQL (`backend "pg"`)

**Configuration Location**:
- Encrypted: `.backend.enc` (committed to git)
- Decrypted: `.backend` (gitignored, local only)

**Configuration Method**:
```bash
terraform init -backend-config=.backend
```

**Why PostgreSQL Backend?**
- **Centralized State**: All team members use the same state
- **State Locking**: Prevents concurrent Terraform runs
- **Version History**: PostgreSQL can maintain history (if configured)
- **Security**: Credentials stored encrypted, not in git
- **Reliability**: Database-backed state is more reliable than local files

#### State Locking

**How It Works**:
- PostgreSQL backend automatically implements state locking
- When Terraform runs, it acquires a lock on the state
- Other Terraform runs wait until the lock is released
- Lock is released when Terraform completes (success or failure)

**Lock Behavior**:
- **Automatic**: No manual intervention needed
- **Per-workspace**: Each workspace has separate locks
- **Timeout**: Locks can be manually released if Terraform crashes

**Handling Lock Errors**:
```bash
# If you see: "Error acquiring the state lock"
# 1. Check if someone else is running Terraform
# 2. Wait for them to finish
# 3. If lock is stale, force unlock (with caution):
terraform force-unlock <lock-id>
```

#### State Encryption

**At Rest**:
- State stored in PostgreSQL (encryption depends on database configuration)
- Backend credentials encrypted in `.backend.enc` (SOPS)

**In Transit**:
- Terraform uses PostgreSQL connection (should use SSL/TLS)
- Backend credentials transmitted securely

**Best Practices**:
- Never commit `.backend` file (contains credentials)
- Always encrypt `.backend.enc` before committing
- Use SSL/TLS for PostgreSQL connections
- Rotate backend credentials periodically

#### Environment Separation Strategy

**Current Approach**: Single Terraform configuration, namespace-based separation

**Environments**:
- **Staging**: `ethos-knapsack-staging`, `fcrepo-staging` namespaces
- **Production**: `ethos-knapsack-production`, `fcrepo` namespaces
- **Shared**: Infrastructure components (ingress, cert-manager, etc.)

**State Management**:
- **Single State File**: All environments in one Terraform state
- **Namespace Isolation**: Logical separation via Kubernetes namespaces
- **Resource Naming**: Resources prefixed/suffixed by namespace

**Alternative Approaches (Not Currently Used)**:
- **Separate Workspaces**: Different Terraform workspaces per environment
- **Separate Configurations**: Different `main.tf` files per environment
- **Separate Backends**: Different PostgreSQL databases per environment

**Trade-offs**:
- **Current (Single State)**: Simpler, easier to manage, shared infrastructure
- **Separate States**: More isolation, but more complex, harder to share resources

**Future Considerations**:
- If environments need complete isolation, consider separate workspaces
- If state becomes too large, consider splitting by environment
- If different teams manage different environments, separate states may be better

#### State Backup and Recovery

**Backup Strategy**:
```bash
# Pull current state
terraform state pull > state-backup-$(date +%Y%m%d).json

# Backup before major changes
terraform state pull > state-backup-before-upgrade.json
```

**Recovery Process**:
1. Identify the issue (corrupted state, accidental deletion, etc.)
2. Restore from backup if available
3. Or use `terraform refresh` to sync state with actual resources
4. Or manually import resources: `terraform import <resource> <id>`

**State Corruption Recovery**:
```bash
# 1. Backup current state
terraform state pull > corrupted-state-backup.json

# 2. Refresh state (syncs with actual resources)
terraform refresh

# 3. Review differences
terraform plan

# 4. If resources are missing, import them
terraform import helm_release.postgresql default/postgresql
```

## Infrastructure Resources

This section documents all AWS and Kubernetes resources provisioned by this OpenTofu configuration.

### AWS Resources

#### IAM Resources

**IAM Policy**: `AWSLoadBalancerControllerIAMPolicy`
- **Purpose**: Grants permissions for AWS Load Balancer Controller to manage ELB resources
- **Key Permissions**:
  - Create/manage Application and Network Load Balancers
  - Create/manage Target Groups
  - Manage security groups and tags
  - Describe EC2 resources (VPCs, subnets, instances)
  - Integrate with WAF, Shield, and ACM certificates
- **Resource**: `aws_iam_policy.aws_load_balancer_controller`

**IAM Role**: `AWSLoadBalancerControllerRole`
- **Purpose**: IAM role assumed by the AWS Load Balancer Controller service account
- **Trust Policy**: OIDC-based (IRSA) - allows `kube-system:aws-load-balancer-controller` service account to assume role
- **Attached Policy**: `AWSLoadBalancerControllerIAMPolicy`
- **Resource**: `aws_iam_role.aws_load_balancer_controller`

**IAM Role Policy Attachment**: Links policy to role
- **Resource**: `aws_iam_role_policy_attachment.aws_load_balancer_controller`

#### Data Sources (Read-Only)

**EKS Cluster Data**: `data.aws_eks_cluster.cluster`
- **Purpose**: Retrieves EKS cluster information (name: `r2-bl-ethos`)
- **Used For**: OIDC issuer URL for IAM role trust policy
- **Region**: `eu-west-1`

**AWS Caller Identity**: `data.aws_caller_identity.current`
- **Purpose**: Retrieves current AWS account ID
- **Used For**: Constructing OIDC provider ARN in IAM role trust policy

**EFS Filesystem**: Read from `efs_name` file
- **Filesystem ID**: `fs-0b4e488025a97af55`
- **Purpose**: Provides persistent shared storage for Kubernetes pods
- **Storage Class**: Exposed as `efs-sc` in Kubernetes

### Kubernetes Resources

#### Namespaces

1. **`kube-system`** (pre-existing)
   - AWS Load Balancer Controller service account

2. **`ingress-nginx`** (created)
   - Ingress NGINX controller

3. **`cert-manager`** (created)
   - cert-manager for certificate management

4. **`default`** (pre-existing, used for)
   - PostgreSQL databases (`postgresql`, `postgresql-17`)
   - Apache Solr

5. **`fcrepo`** (created)
   - Fedora Repository production instance
   - PostgreSQL for Fedora

6. **`fcrepo-staging`** (created)
   - Fedora Repository staging instance
   - PostgreSQL for Fedora staging

7. **`ethos-knapsack-staging`** (created)
   - Staging application namespace
   - Rancher project annotations

8. **`ethos-knapsack-production`** (created)
   - Production application namespace
   - Rancher project annotations

#### Service Accounts

**`aws-load-balancer-controller`** (namespace: `kube-system`)
- **Purpose**: Service account for AWS Load Balancer Controller
- **IAM Integration**: Annotated with IAM role ARN for IRSA
- **Resource**: `kubernetes_service_account.aws_load_balancer_controller`

#### Storage Classes

**`efs-sc`** (EFS Storage Class)
- **Provisioner**: `efs.csi.aws.com`
- **Filesystem ID**: `fs-0b4e488025a97af55` (from `efs_name` file)
- **Provisioning Mode**: `efs-ap` (Access Point)
- **Directory Permissions**: `700`
- **Resource**: `kubernetes_storage_class.storage_class`

**`gp2`** (EBS Storage Class)
- **Note**: Pre-existing default storage class in EKS
- **Used by**: PostgreSQL databases for persistent volumes

#### Helm Releases

**Infrastructure Components:**

1. **`aws-load-balancer-controller`** (namespace: `kube-system`)
   - **Chart**: `aws-load-balancer-controller` from AWS EKS Charts
   - **Purpose**: Manages AWS Application/Network Load Balancers
   - **Configuration**: Cluster name, VPC ID, service account
   - **Dependencies**: Service account must exist first

2. **`ingress-nginx`** (namespace: `ingress-nginx`)
   - **Chart**: `ingress-nginx` v4.5.2 from Kubernetes
   - **Purpose**: HTTP/HTTPS ingress controller
   - **Configuration**: Values from `k8s/ingress-nginx-values.yaml`
   - **Dependencies**: AWS Load Balancer Controller

3. **`cert-manager`** (namespace: `cert-manager`)
   - **Chart**: `cert-manager` v1.17.1 from Jetstack
   - **Purpose**: Automated certificate management
   - **Configuration**: CRDs installed automatically

**Application Dependencies:**

4. **`postgresql`** (namespace: `default`)
   - **Chart**: Bitnami PostgreSQL
   - **Purpose**: Main application database
   - **Configuration**: Values from `k8s/postgresql-values.yaml`

5. **`postgresql-17`** (namespace: `default`)
   - **Chart**: Bitnami PostgreSQL v16.7.27
   - **Purpose**: PostgreSQL 17 instance
   - **Configuration**: Values from `k8s/postgresql-17-production-values.yaml`

6. **`postgresql`** (namespace: `fcrepo`)
   - **Chart**: Bitnami PostgreSQL
   - **Purpose**: Fedora Repository production database
   - **Configuration**: Values from `k8s/postgresql-values.yaml`

7. **`postgresql`** (namespace: `fcrepo-staging`)
   - **Chart**: Bitnami PostgreSQL
   - **Purpose**: Fedora Repository staging database
   - **Configuration**: Values from `k8s/postgresql-values.yaml`

8. **`solr`** (namespace: `default`)
   - **Chart**: Bitnami Solr
   - **Purpose**: Search engine with ZooKeeper
   - **Configuration**: Values from `k8s/solr-values.yaml`

9. **`fcrepo`** (namespace: `fcrepo`)
   - **Chart**: Fedora from Samvera Labs
   - **Purpose**: Fedora Repository production instance
   - **Configuration**: Values from `k8s/fcrepos3-values.yaml`
   - **Dependencies**: PostgreSQL in `fcrepo` namespace

10. **`fcrepo-staging`** (namespace: `fcrepo-staging`)
    - **Chart**: Fedora from Samvera Labs
    - **Purpose**: Fedora Repository staging instance
    - **Configuration**: Values from `k8s/fcrepos3-values.yaml`
    - **Dependencies**: PostgreSQL in `fcrepo-staging` namespace

#### Kubernetes Manifests (via kubectl provider)

1. **Cloudflare API Token Secret** (`kubectl_manifest.cloudflare-api-token-secret`)
   - **Purpose**: Secret for Cloudflare DNS-01 challenge
   - **Source**: `k8s/cloudflare-api-token-secret.yaml`
   - **Dependencies**: cert-manager

2. **Let's Encrypt Production Issuer** (`kubectl_manifest.prod_issuer`)
   - **Purpose**: ClusterIssuer for Let's Encrypt HTTP-01 challenge
   - **Source**: `k8s/prod_issuer.yaml`
   - **Dependencies**: cert-manager

3. **Let's Encrypt Production DNS Issuer** (`kubectl_manifest.prod_issuer_dns`)
   - **Purpose**: ClusterIssuer for Let's Encrypt DNS-01 challenge (Cloudflare)
   - **Source**: `k8s/prod-issuer-dns-values.yaml`
   - **Dependencies**: cert-manager, Cloudflare API token secret

4. **GitHub Registry Secret - Staging** (`kubectl_manifest.github-registry-secret-staging`)
   - **Purpose**: Docker registry credentials for `ethos-knapsack-staging` namespace
   - **Source**: `k8s/github-registry-secret-values.yaml` (templated)
   - **Namespace**: `ethos-knapsack-staging`

5. **GitHub Registry Secret - Production** (`kubectl_manifest.github-registry-secret-production`)
   - **Purpose**: Docker registry credentials for `ethos-knapsack-production` namespace
   - **Source**: `k8s/github-registry-secret-values.yaml` (templated)
   - **Namespace**: `ethos-knapsack-production`

### Resource Dependencies

The following dependency order is enforced:

1. **IAM Resources** (policy, role, attachment)
2. **Service Accounts** (AWS Load Balancer Controller)
3. **AWS Load Balancer Controller** Helm release
4. **Ingress NGINX** Helm release
5. **cert-manager** Helm release
6. **Certificate Issuers** (kubectl manifests)
7. **Storage Classes** (EFS)
8. **PostgreSQL Databases** (all namespaces)
9. **Fedora Repository** (depends on PostgreSQL)
10. **Solr** (independent)
11. **Application Namespaces** (independent)
12. **Registry Secrets** (independent)

### External Dependencies (Not Managed by Terraform)

- **EKS Cluster**: `r2-bl-ethos` (must exist)
- **VPC**: `vpc-0e75da99cc686b282` (must exist)
- **EFS Filesystem**: `fs-0b4e488025a97af55` (must exist)
- **S3 Bucket**: `samvera-fcrepo-bl-ethos` (for Fedora object storage)
- **Cloudflare**: DNS provider for certificate DNS-01 challenges
- **PostgreSQL Backend**: For Terraform state storage
- **OIDC Provider**: Configured on EKS cluster for IRSA

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
4. **Verify SOPS Key Setup**
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

## Infrastructure Management Training

This section provides beginner-friendly guidance for working with this infrastructure. It assumes familiarity with AWS basics but no prior OpenTofu/Terraform experience.

### Understanding This Infrastructure

#### What is Infrastructure as Code (IaC)?

Infrastructure as Code (IaC) means defining your infrastructure (servers, databases, networks, etc.) in code files, just like application code. This allows you to:
- **Version control** your infrastructure changes
- **Reproduce** environments consistently
- **Review** changes before applying them
- **Document** what resources exist and why

#### What is OpenTofu/Terraform?

OpenTofu (formerly Terraform) is an IaC tool that:
- Reads configuration files (`.tf` files) that describe desired infrastructure
- Compares desired state with actual state
- Creates, updates, or destroys resources to match desired state
- Tracks state in a backend (in our case, PostgreSQL)

**Key Concepts:**
- **Configuration**: `.tf` files that describe what you want
- **State**: Current state of all resources (stored in PostgreSQL backend)
- **Plan**: Preview of what will change (run `terraform plan`)
- **Apply**: Actually make the changes (run `terraform apply`)

#### How This Infrastructure Works

**Architecture Flow:**

1. **You write/update** `.tf` files describing infrastructure
2. **Terraform reads** configuration and current state
3. **Terraform calculates** differences (plan)
4. **You review** the plan
5. **Terraform applies** changes (if approved)
6. **State is updated** in PostgreSQL backend

**What Gets Created:**

When you run `terraform apply`, it creates:
- **AWS IAM resources** (roles, policies) for service authentication
- **Kubernetes namespaces** for organizing resources
- **Helm releases** (packaged applications) like PostgreSQL, Solr, etc.
- **Kubernetes resources** like storage classes, secrets, service accounts
- **Certificate issuers** for automatic SSL certificate management

**What Doesn't Get Created:**

- The EKS cluster itself (pre-existing)
- The VPC (pre-existing)
- The EFS filesystem (pre-existing)
- The S3 bucket (pre-existing)

### Step-by-Step: Using OpenTofu Safely

#### Step 1: Understanding the Workflow

**Standard Workflow:**
```
1. Decrypt secrets → 2. Initialize → 3. Plan → 4. Review → 5. Apply
```

**Never skip steps 3 and 4!** Always plan and review before applying.

#### Step 2: Initial Setup (First Time Only)

**2.1 Install Tools**

```bash
# Install OpenTofu
brew install opentofu/tap/opentofu

# Install SOPS (for secrets)
brew install sops

# Verify installations
tofu version  # or: terraform version
sops --version
```

**2.2 Set Up SOPS Key**

See [Setting Up SOPS Key](#setting-up-sops-key) in the Getting Access section.

**2.3 Configure AWS Access**

```bash
# Verify AWS credentials
aws sts get-caller-identity

# If not configured:
aws configure
# Enter: Access Key ID, Secret Access Key, Region (eu-west-1), Output format (json)
```

**2.4 Navigate to Provision Directory**

```bash
cd ops/provision
```

#### Step 3: Decrypt Secrets

**Why?** Secret files are encrypted in git. You need to decrypt them to use Terraform.

```bash
# From repository root
cd ../..  # if you're in ops/provision
bin/decrypt-secrets
```

**What this does:**
- Decrypts `.backend.enc` → `.backend` (Terraform backend config)
- Decrypts `kube_config.enc.yml` → `kube_config.yml` (Kubernetes access)
- Decrypts `k8s/*-values.enc.yaml` → `k8s/*-values.yaml` (Helm values with secrets)

**If this fails:** You haven't set up your SOPS key yet. See [Setting Up SOPS Key](#setting-up-sops-key).

#### Step 4: Initialize Terraform

**When to run:** First time, or after pulling changes that update providers.

```bash
cd ops/provision
terraform init -backend-config=.backend
```

**What this does:**
- Downloads required providers (AWS, Kubernetes, Helm, kubectl)
- Configures PostgreSQL backend connection
- Creates `.terraform/` directory with provider plugins

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

**Common issues:**
- **Backend connection error**: Check `.backend` file exists and PostgreSQL is accessible
- **Provider download fails**: Check internet connection
- **Version conflicts**: Run `terraform init -upgrade` to update providers

#### Step 5: Plan Changes (ALWAYS DO THIS FIRST)

**Purpose:** Preview what will change without making any changes.

```bash
terraform plan
```

**Understanding the Output:**

- **`+`** (green): Resource will be **created**
- **`~`** (yellow): Resource will be **modified** (in-place update)
- **`-`** (red): Resource will be **destroyed**
- **`-/+`** (red/yellow): Resource will be **replaced** (destroyed and recreated)
- **`<=`**: Resource will be **read** (data source)

**Example output:**
```
# aws_iam_role.aws_load_balancer_controller will be created
+ resource "aws_iam_role" "aws_load_balancer_controller" {
    ...
}

# helm_release.postgresql will be modified
~ resource "helm_release" "postgresql" {
    ~ version = "12.1.0" -> "12.2.0"
    ...
}

Plan: 1 to add, 1 to change, 0 to destroy.
```

**Saving Plans for Review:**

```bash
# Save plan to file
terraform plan -out=tfplan

# Review saved plan
terraform show tfplan

# Apply saved plan later
terraform apply tfplan
```

**Targeted Planning (specific resources):**

```bash
# Plan only PostgreSQL changes
terraform plan -target=helm_release.postgresql

# Plan multiple specific resources
terraform plan -target=helm_release.postgresql -target=helm_release.solr
```

**Best Practices:**
- ✅ Always run `plan` before `apply`
- ✅ Review the plan carefully, especially for destructive changes (`-` or `-/+`)
- ✅ Save plans for complex changes: `terraform plan -out=tfplan`
- ✅ Share plan output for code reviews
- ❌ Never skip the plan step

#### Step 6: Review the Plan

**What to Look For:**

1. **Unexpected Changes**
   - Are resources being destroyed that shouldn't be?
   - Are values changing that you didn't intend to modify?

2. **Destructive Operations** (`-` or `-/+`)
   - **Databases**: Destroying PostgreSQL will **delete all data**!
   - **Load Balancers**: May cause brief service interruption
   - **IAM Roles**: May break running services temporarily

3. **Resource Counts**
   - Check "Plan: X to add, Y to change, Z to destroy"
   - If Z > 0, verify those resources should be destroyed

4. **Dependency Order**
   - Resources are created in dependency order
   - Verify dependencies make sense

**Red Flags:**
- ⚠️ Unexpected resource destruction
- ⚠️ Database resources being replaced
- ⚠️ Large number of changes you didn't expect
- ⚠️ Changes to IAM roles/policies (may break services)

**If Something Looks Wrong:**
- Stop and investigate
- Check recent changes to configuration
- Ask team members
- Review git history

#### Step 7: Apply Changes

**When you're confident the plan is correct:**

```bash
terraform apply
```

**What Happens:**

1. Terraform shows the plan again
2. Prompts for confirmation: `Do you want to perform these actions?`
3. Type `yes` to proceed (or `no` to cancel)
4. Terraform creates/modifies/destroys resources
5. Updates state in PostgreSQL backend

**Non-Interactive Mode (Use with Caution):**

```bash
terraform apply -auto-approve
```

**⚠️ Warning:** Only use `-auto-approve` in CI/CD or when absolutely certain. Never use for destructive operations.

**Applying a Saved Plan:**

```bash
# If you saved a plan earlier
terraform apply tfplan
```

**Targeted Apply (specific resources):**

```bash
# Apply only PostgreSQL changes
terraform apply -target=helm_release.postgresql
```

**During Apply:**

- Watch for errors
- Some resources take time (databases, load balancers)
- Don't interrupt the process (Ctrl+C can leave resources in inconsistent state)

**After Apply:**

```bash
# Verify resources were created
terraform state list

# Check specific resource
terraform state show helm_release.postgresql

# Verify in Kubernetes
kubectl --kubeconfig=kube_config.yml get pods -A
```

#### Step 8: Verify Changes

**Check Terraform State:**

```bash
# List all managed resources
terraform state list

# Show details of a resource
terraform state show helm_release.postgresql

# Verify state matches reality
terraform refresh  # Updates state from actual resources
```

**Check Kubernetes Resources:**

```bash
# List all pods
kubectl --kubeconfig=kube_config.yml get pods -A

# Check specific namespace
kubectl --kubeconfig=kube_config.yml get all -n default

# Check Helm releases
helm list -A --kubeconfig kube_config.yml

# Check pod logs if issues
kubectl --kubeconfig=kube_config.yml logs -n default postgresql-0
```

**Check AWS Resources:**

```bash
# Verify IAM role exists
aws iam get-role --role-name AWSLoadBalancerControllerRole

# Check EKS cluster
aws eks describe-cluster --name r2-bl-ethos --region eu-west-1
```

### Making and Reviewing Changes

#### Workflow for Infrastructure Changes

**1. Create a Feature Branch**

```bash
git checkout -b your-branch-name
```

**2. Make Your Changes**

Edit files in `ops/provision/`:
- `main.tf` - Main configuration
- `k8s/*-values.yaml` - Helm chart values (after decrypting)

**3. Test Locally**

```bash
cd ops/provision

# Update providers if needed
terraform init -upgrade

# Validate syntax
terraform validate

# Plan changes
terraform plan
```

**4. Review Your Plan**

- Check for unexpected changes
- Verify resource counts
- Look for destructive operations
- Save plan for review: `terraform plan -out=tfplan`

**5. Get Code Review**

```bash
# Commit your changes
git add ops/provision/main.tf
git commit -m "Update PostgreSQL version"

# Push branch
git push origin your-branch-name

# Create pull request
```

**What to Include in PR:**
- Description of changes
- Plan output (or link to saved plan)
- Impact assessment
- Testing performed

**6. Apply After Approval**

- Merge PR to main
- Apply in appropriate environment
- Monitor for issues

#### Common Change Scenarios

**Scenario 1: Updating a Helm Chart Version**

```hcl
# In main.tf, find the helm_release resource
resource "helm_release" "postgresql" {
  # ... existing config ...
  version = "12.2.0"  # Change this
  # ... rest of config ...
}
```

**Steps:**
1. Update version in `main.tf`
2. Run `terraform plan` to see changes
3. Review Helm chart release notes for breaking changes
4. Apply during maintenance window if needed

**Scenario 2: Modifying Resource Configuration**

**Option A: Edit main.tf directly**
```hcl
resource "helm_release" "postgresql" {
  # Add or modify set blocks
  set {
    name  = "postgresqlPassword"
    value = "newpassword"
  }
}
```

**Option B: Edit values files**
```bash
# Decrypt first
bin/decrypt-secrets

# Edit values file
ops/provision/k8s/postgresql-values.yaml

# Encrypt after changes
bin/encrypt-secrets
```

**Steps:**
1. Make changes
2. Run `terraform plan`
3. Review changes
4. Apply

**Scenario 3: Adding a New Helm Release**

```hcl
# Add to main.tf
resource "helm_release" "new_service" {
  name       = "new-service"
  namespace  = "default"
  repository = "https://charts.example.com"
  chart      = "service-chart"
  version    = "1.0.0"

  values = [file("k8s/new-service-values.yaml")]
}
```

**Steps:**
1. Add resource to `main.tf`
2. Create values file in `k8s/` directory
3. Run `terraform plan`
4. Review and apply

**Scenario 4: Adding Environment Variables or Secrets**

**For Kubernetes Secrets:**

```bash
# Create secret YAML file
ops/provision/k8s/my-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
data:
  password: <base64-encoded-value>
```

```hcl
# Add to main.tf
resource "kubectl_manifest" "my_secret" {
  yaml_body = file("./k8s/my-secret.yaml")
}
```

**For Helm Values:**

```bash
# Decrypt first
bin/decrypt-secrets

# Edit values file
ops/provision/k8s/postgresql-values.yaml
# Add environment variables or secrets

# Encrypt after changes
bin/encrypt-secrets
```

**⚠️ Security Note:** Never commit plain-text secrets. Always encrypt before committing.

### Understanding Terraform State

#### What is State?

State is Terraform's record of what resources it manages and their current configuration. It's stored in the PostgreSQL backend.

**Why State Matters:**
- Terraform uses state to know what exists
- Without state, Terraform would try to create everything again
- State enables Terraform to update or destroy resources

**State Location:**
- **Backend**: PostgreSQL database (configured in `.backend` file)
- **Not in git**: State files are never committed
- **Centralized**: All team members use the same state

#### State Locking

**What is Locking?**
- Prevents multiple people from running Terraform simultaneously
- Ensures state consistency
- Automatic when using PostgreSQL backend

**If You See a Lock Error:**
```
Error: Error acquiring the state lock
```

**Solutions:**
1. Wait if someone else is running Terraform
2. Check with team members
3. Force unlock (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```

#### State Management Best Practices

**✅ Do:**
- Always run `terraform plan` before `apply`
- Review state changes in plan output
- Use `terraform state list` to see managed resources
- Backup state before major changes: `terraform state pull > backup.json`

**❌ Don't:**
- Manually edit state files
- Delete state without backing up
- Run Terraform in multiple terminals simultaneously
- Share state files via email/chat

### Destroying Resources

#### When to Destroy

**Appropriate:**
- Cleaning up test environments
- Removing unused resources
- Complete infrastructure teardown
- Disaster recovery scenarios

**⚠️ Dangerous:**
- Production environments
- Resources with important data (databases)
- Shared infrastructure

#### How to Destroy

**Destroy Everything:**

```bash
terraform destroy
```

**⚠️ WARNING:** This will delete **all** resources, including databases with data!

**Destroy Specific Resources:**

```bash
# Destroy only PostgreSQL
terraform destroy -target=helm_release.postgresql

# Destroy multiple specific resources
terraform destroy -target=helm_release.postgresql -target=helm_release.solr
```

**Best Practices:**
- ✅ Always run `terraform plan -destroy` first to see what will be destroyed
- ✅ Backup databases before destroying
- ✅ Double-check you're in the right environment
- ✅ Use with extreme caution in production
- ❌ Never destroy without reviewing the plan first

### Next Steps

After completing this training:

1. **Practice**: Make a small change (e.g., update a Helm chart version) in a test branch
2. **Review**: Have a team member review your plan output
3. **Learn More**: Read Terraform documentation and AWS/EKS best practices
4. **Ask Questions**: Don't hesitate to ask the infrastructure team

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
   ops/provision/k8s/postgresql-values.yaml
   ops/provision/.backend
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

### External Resources
- [OpenTofu Documentation](https://opentofu.org/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [tfswitch](https://github.com/warrensbox/terraform-switcher) - Terraform version manager

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
