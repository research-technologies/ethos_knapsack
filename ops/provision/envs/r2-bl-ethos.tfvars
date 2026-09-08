# r2-bl-ethos cluster (BL account, eu-west-1) — use with: AWS_PROFILE=bl terraform plan -var-file=envs/r2-bl-ethos.tfvars
#
# Import existing EKS cluster into this repo (same pattern as notch8-ops). Workspace "r2-bl-ethos" holds the imported state.
# Run scripts/discover-eks-ids.sh with profile bl first, then merge scripts/import-tfvars-snippet-r2-bl-ethos.txt
# into this file for IAM/node group overrides. See docs/EKS_IMPORT.md.

cluster_name = "r2-bl-ethos"
region       = "eu-west-1"
k8s_version  = "1.34"

assume_role_arn = "arn:aws:iam::822951369940:role/ScientistAccess"   # Replace account ID if different

# From discover: node group "solr", scaling and instance type match AWS
node_group_name     = "solr"
node_instance_type  = "m5.2xlarge"
desired_size        = 6
min_size            = 6
max_size            = 8

enable_lb_controller = false
enable_scientist_access     = true   # EKS access entry + ClusterAdmin for ScientistAccess (like friends, besteis, tools)
manage_kube_proxy_addon     = false  # Rancher-created cluster: kube-proxy not an EKS addon
enable_cluster_config_output = false

# From discover: IAM role names (actual in AWS)
cluster_iam_role_name = "RancherRole"
node_iam_role_name    = "r2-bl-ethos-node-instance-role-NodeInstanceRole-j927rB8cLnH0"
ebs_csi_role_name     = "ebs-csi-driver-role"
efs_csi_role_name     = "efs-csi-driver-role"

# EFS ID
efs_file_system_id   = "fs-0b4e488025a97af55"

# GitHub usernames for SSH key access on nodes (matches current AWS LT: orangewolf, aprilrieger, maxkadel)
admin_github_users   = ["orangewolf", "aprilrieger", "maxkadel"]

enable_site24x7      = true
# Site24x7 group name (matches current AWS LT: BritishLibraryEthos). Key is in .secret.tfvars
site24x7_group       = "BritishLibraryEthos"

# Launch template in use: lt-02d926ad95d14f8e8 (version 2) — use --region eu-west-1 to describe

# Sensitive values (Site24x7 keys, Zoho OAuth, etc.): use envs/r2-bl-ethos.secret.tfvars
# Copy envs/r2-bl-ethos.secret.tfvars.example to r2-bl-ethos.secret.tfvars, fill in, then:
#   bin/encrypt-secrets   → creates .secret.tfvars.enc (commit that)
#   bin/decrypt-secrets   → before plan/apply
#   terraform plan -var-file=envs/r2-bl-ethos.tfvars -var-file=envs/r2-bl-ethos.secret.tfvars