resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.k8s_version

  # CRITICAL: Enable deletion protection to prevent accidental cluster deletion
  # This prevents deletion even if Rancher or other tools have delete permissions.
  # Based on incident analysis: cluster r2-gbh-ams2 was deleted because deletion_protection was false
  deletion_protection = true

  vpc_config {
    subnet_ids = [
      aws_subnet.public_az1.id,
      aws_subnet.public_az2.id,
      aws_subnet.public_az3.id
    ]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Imported: do not change vpc_config (subnets, endpoint settings)
  # version is managed so cluster matches var.k8s_version; keep tfvars in sync when upgrading.
  lifecycle {
    ignore_changes = [access_config, bootstrap_self_managed_addons, tags, tags_all, enabled_cluster_log_types, vpc_config]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}
