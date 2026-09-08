variable "assume_role_arn" {
  description = "IAM role ARN to assume for EKS/Kubernetes operations (e.g., ScientistAccess)"
  type        = string
  default     = "arn:aws:iam::559021623471:role/ScientistAccess"
}

variable "region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region name for deployment"
}

variable "cluster_name" {
  type        = string
  description = "Kubernetes cluster name"
}

variable "eks_ami_id" {
  description = "Optional AMI ID for EKS nodes. If empty, use latest recommended from SSM."
  type        = string
  default     = ""
}

variable "k8s_version" {
  description = "Kubernetes version for the cluster (must be a version supported by AWS EKS - check https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html). Set per environment in tfvars; no default so each workspace declares its version explicitly."
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.micro"
}

variable "node_root_volume_size" {
  description = "Root (ephemeral) volume size in GiB for EKS nodes. Unset uses AMI default (typically 20 GiB)."
  type        = number
  default     = null
}

variable "desired_size" {
  type        = number
  default     = 1
  description = "Desired number of nodes in the node group"
}

variable "max_size" {
  type        = number
  default     = 2
  description = "Maximum number of nodes in the node group"
}

variable "min_size" {
  type        = number
  default     = 1
  description = "Minimum number of nodes in the node group"
}

variable "scientist_access_role_name" {
  description = "IAM role name to grant cluster access (e.g., ScientistAccess)"
  type        = string
  default     = "ScientistAccess"
}

# When importing a cluster created with different IAM role names, set these so Terraform doesn't try to rename
variable "cluster_iam_role_name" {
  description = "Override EKS cluster IAM role name (set to actual name when importing, e.g. from discover script)"
  type        = string
  default     = ""
}

variable "node_iam_role_name" {
  description = "Override EKS node IAM role name (set to actual name when importing)"
  type        = string
  default     = ""
}

variable "ebs_csi_role_name" {
  description = "Override EBS CSI IRSA role name (set to actual name when importing, from addon serviceAccountRoleArn)"
  type        = string
  default     = ""
}

variable "efs_csi_role_name" {
  description = "Override EFS CSI IRSA role name (set to actual name when importing)"
  type        = string
  default     = ""
}

variable "efs_creation_token" {
  description = "Override EFS creation_token (set when importing to avoid replace, e.g. friends-efs)"
  type        = string
  default     = ""
}

variable "efs_name" {
  description = "Override EFS Name tag / display name (set when importing, e.g. friendsEFS)"
  type        = string
  default     = ""
}

variable "efs_security_group_id" {
  description = "Use existing EFS security group for mount targets (set when importing to avoid creating a new SG). When set, Terraform will not create aws_security_group.ingress-efs."
  type        = string
  default     = ""
}

variable "efs_file_system_id" {
  description = "EFS file system ID for the efs-sc StorageClass. Set in tfvars or leave empty to skip."
  type        = string
  default     = ""
}

variable "node_group_name" {
  description = "Override EKS node group name (set when importing to avoid replace, e.g. large-al2023-3)"
  type        = string
  default     = ""
}

# Bootstrap configuration variables
variable "enable_lb_controller" {
  description = "Install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

# Infra-only clusters (e.g. imported r2-friends): set these false so plan shows 0 to add
variable "enable_scientist_access" {
  description = "Create EKS access entry + policy for ScientistAccess role (cluster admin)"
  type        = bool
  default     = true
}

variable "manage_kube_proxy_addon" {
  description = "Manage kube-proxy as an EKS addon. Set to false for Rancher-created clusters (Rancher deploys kube-proxy in-cluster)."
  type        = bool
  default     = true
}

variable "enable_cluster_config_output" {
  description = "Write cluster config YAML to clusters/<name>/config.yaml (for tooling that consumes cluster config)"
  type        = bool
  default     = true
}

variable "nginx_ingress_chart_version" {
  description = "Version of the NGINX Ingress Helm chart to install"
  type        = string
  default     = "2.4.3"
}

variable "admin_github_users" {
  description = "List of GitHub usernames to add SSH keys for admin access"
  type        = list(string)
  default     = ["aprilrieger", "maxkadel"]
}

# Site24x7 monitoring agent on EKS nodes (user_data.txt)
variable "enable_site24x7" {
  description = "Install Site24x7 monitoring agent on node bootstrap (user_data)"
  type        = bool
  default     = false
}

variable "site24x7_key" {
  description = "Site24x7 agent license key (when enable_site24x7 is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "site24x7_group" {
  description = "Site24x7 monitor group name (when enable_site24x7 is true)"
  type        = string
  default     = ""
}

variable "site24x7_zoho_client_id" {
  description = "Zoho OAuth client ID for Site24x7 API (optional, for manage script)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "site24x7_zoho_client_secret" {
  description = "Zoho OAuth client secret for Site24x7 API"
  type        = string
  default     = ""
  sensitive   = true
}

variable "site24x7_zoho_refresh_token" {
  description = "Zoho OAuth refresh token for Site24x7 API"
  type        = string
  default     = ""
  sensitive   = true
}

variable "site24x7_third_party_services" {
  description = "Comma-separated Site24x7 third-party service IDs"
  type        = string
  default     = ""
}

variable "site24x7_monitor_group_id" {
  description = "Site24x7 monitor group ID (optional if site24x7_group is set)"
  type        = string
  default     = ""
}

# =============================================================================
# Cluster Config Generation Variables
# =============================================================================

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

# Platform service versions
variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "1.19.3"
}

variable "external_secrets_version" {
  description = "Version of external-secrets Helm chart"
  type        = string
  default     = "1.3.2"
}

variable "postgres_operator_version" {
  description = "Version of Zalando postgres-operator Helm chart"
  type        = string
  default     = "1.15.0"
}

# Resource sizing
variable "solr_replicas" {
  description = "Number of Solr replicas"
  type        = number
  default     = 1
}

variable "solr_memory" {
  description = "Memory limit for Solr pods"
  type        = string
  default     = "2Gi"
}

variable "solr_storage" {
  description = "Storage size for Solr PVCs"
  type        = string
  default     = "50Gi"
}

variable "solr_admin_password_1password_item" {
  description = "1Password item title for Solr admin password (DevOps vault). ExternalSecret remoteRef.key."
  type        = string
  default     = ""
}

variable "postgres_instances" {
  description = "Number of PostgreSQL instances"
  type        = number
  default     = 2
}

variable "postgres_memory" {
  description = "Memory limit for PostgreSQL pods"
  type        = string
  default     = "4Gi"
}

variable "postgres_storage" {
  description = "Storage size for PostgreSQL PVCs"
  type        = string
  default     = "100Gi"
}

variable "zookeeper_replicas" {
  description = "Number of Zookeeper replicas"
  type        = number
  default     = 1
}

# Feature flags
variable "enable_logical_backups" {
  description = "Enable PostgreSQL logical backups to S3"
  type        = bool
  default     = true
}


