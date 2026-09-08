# EKS cluster endpoint (sensitive to avoid leaking API URL in logs)
output "cluster_endpoint" {
  description = "The endpoint for the Kubernetes API server"
  value       = aws_eks_cluster.cluster.endpoint
  sensitive   = true
}

# Cluster name
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.cluster.name
}

# Cluster IAM role ARN
output "cluster_role_arn" {
  description = "IAM role ARN used by the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

# Cluster security group ID
output "cluster_security_group_id" {
  description = "The security group ID created by EKS for the cluster"
  value       = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

# Cluster status
output "cluster_status" {
  description = "Current status of the EKS cluster"
  value       = aws_eks_cluster.cluster.status
}

# Cluster version
output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.cluster.version
}

# Deletion protection (should be true in production)
output "cluster_deletion_protection" {
  description = "Whether EKS cluster deletion protection is enabled"
  value       = aws_eks_cluster.cluster.deletion_protection
}

# OIDC Provider ARN for IRSA
output "oidc_provider_arn" {
  description = "ARN of the OIDC identity provider for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

# Dynamically created VPC ID
output "vpc_id" {
  description = "ID of the dynamically created VPC for the cluster"
  value       = aws_vpc.main.id
}

# Dynamically created subnet IDs
output "subnet_ids" {
  description = "IDs of the dynamically created subnets for the cluster"
  value = [
    aws_subnet.az1.id,
    aws_subnet.az2.id,
    aws_subnet.az3.id
  ]
}

# Public subnet IDs for load balancers
output "public_subnet_ids" {
  description = "IDs of the public subnets for load balancers"
  value = [
    aws_subnet.public_az1.id,
    aws_subnet.public_az2.id,
    aws_subnet.public_az3.id
  ]
}

# NAT Gateway public IP
output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# Public route table: ensures 0.0.0.0/0 -> IGW for NLB response path
output "public_route_table_id" {
  description = "Route table used by public subnets (must have 0.0.0.0/0 -> Internet Gateway)"
  value       = aws_route_table.public.id
}

output "public_route_table_default_gateway" {
  description = "Public route table 0.0.0.0/0 gateway (should be igw-xxx for internet-facing NLB)"
  value       = aws_route.public_inet.gateway_id
}

# Kubeconfig setup command (sensitive: contains role ARN)
output "kubeconfig_setup" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.cluster.name} --region ${var.region} --role-arn ${var.assume_role_arn}"
  sensitive   = true
}

# AWS Region
output "region" {
  description = "AWS region where resources are deployed"
  value       = var.region
}

# ------------------------------------------------------------------------------
# Add-on / platform versions — audit trail and reproducibility
# ------------------------------------------------------------------------------
# These are the versions configured for this apply. Use for:
# - Audit: see exactly what was deployed (tofu output addon_versions).
# - Reproducibility: copy this block or the generated config.yaml to recreate the
#   same combo elsewhere, or pin a new env to these versions in tfvars.
# Source of truth remains tfvars + variables.tf; this output is a convenience
# so you don't have to grep tfvars or config.yaml after apply.
# ------------------------------------------------------------------------------
output "addon_versions" {
  description = "All add-on and platform component versions for this cluster (audit trail and reproducibility)"
  value = {
    kubernetes = {
      requested = var.k8s_version
      # Actual EKS cluster version (may differ if upgrade in progress)
      cluster = aws_eks_cluster.cluster.version
    }
    eks_addons = merge(
      {
        aws_ebs_csi_driver = data.aws_eks_addon_version.ebs_csi.version
        aws_efs_csi_driver = data.aws_eks_addon_version.efs_csi.version
      },
      var.manage_kube_proxy_addon ? { kube_proxy = data.aws_eks_addon_version.kube_proxy[0].version } : {}
    )
    helm_platform = {
      cert_manager      = var.cert_manager_version
      external_secrets  = var.external_secrets_version
      nginx_ingress     = var.nginx_ingress_chart_version
      postgres_operator = var.postgres_operator_version
    }
  }
}

