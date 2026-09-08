# Cluster-level workloads: LB controller (optional), EFS StorageClass.

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller (single implementation; gated by enable_lb_controller)
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "provision_lb_controller" {
  count       = var.enable_lb_controller ? 1 : 0
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role" "provision_lb_controller" {
  count  = var.enable_lb_controller ? 1 : 0
  name   = "AWSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_hostpath}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "provision_lb_controller" {
  count      = var.enable_lb_controller ? 1 : 0
  policy_arn = aws_iam_policy.provision_lb_controller[0].arn
  role       = aws_iam_role.provision_lb_controller[0].name
}

resource "kubernetes_service_account" "provision_lb_controller" {
  count = var.enable_lb_controller ? 1 : 0
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.provision_lb_controller[0].arn
    }
  }
}

resource "helm_release" "provision_aws_load_balancer" {
  count       = var.enable_lb_controller ? 1 : 0
  chart       = "aws-load-balancer-controller"
  name        = "aws-load-balancer-controller"
  namespace   = "kube-system"
  repository  = "https://aws.github.io/eks-charts"
  depends_on  = [kubernetes_service_account.provision_lb_controller]
  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }
}

# -----------------------------------------------------------------------------
# EFS Storage Class (set efs_file_system_id in tfvars)
# -----------------------------------------------------------------------------
resource "kubernetes_storage_class" "efs" {
  count               = var.efs_file_system_id != "" ? 1 : 0
  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    directoryPerms    = "700"
    fileSystemId     = var.efs_file_system_id
    provisioningMode = "efs-ap"
  }
  metadata {
    name = "efs-sc"
  }
}
