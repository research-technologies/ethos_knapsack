data "aws_iam_role" "scientist_access" {
  count  = var.enable_scientist_access ? 1 : 0
  name   = var.scientist_access_role_name
}

# Grant ScientistAccess role EKS Console admin access
resource "aws_eks_access_entry" "scientist" {
  count          = var.enable_scientist_access ? 1 : 0
  cluster_name   = aws_eks_cluster.cluster.name
  principal_arn  = data.aws_iam_role.scientist_access[0].arn
  type           = "STANDARD"

  depends_on = [aws_eks_cluster.cluster]
}

resource "aws_eks_access_policy_association" "scientist_admin" {
  count          = var.enable_scientist_access ? 1 : 0
  cluster_name   = aws_eks_cluster.cluster.name
  principal_arn  = data.aws_iam_role.scientist_access[0].arn
  policy_arn     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.scientist]
}
