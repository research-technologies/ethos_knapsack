resource "aws_iam_openid_connect_provider" "cluster" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # Public AWS root CA thumbprint for EKS OIDC (common)
  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  ]

  tags = {
    Name        = "${var.cluster_name}-oidc-provider"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    ignore_changes = [tags, tags_all, thumbprint_list]
  }
}

locals {
  oidc_hostpath = replace(aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
}

# EBS CSI Controller IRSA role
resource "aws_iam_role" "ebs_csi" {
  name = var.ebs_csi_role_name != "" ? var.ebs_csi_role_name : "${var.cluster_name}-EBSCSIRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_hostpath}:aud" : "sts.amazonaws.com",
            "${local.oidc_hostpath}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name        = var.ebs_csi_role_name != "" ? var.ebs_csi_role_name : "${var.cluster_name}-ebs-csi-role"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EFS CSI Controller IRSA role
resource "aws_iam_role" "efs_csi" {
  name = var.efs_csi_role_name != "" ? var.efs_csi_role_name : "${var.cluster_name}-EFSCSIRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_hostpath}:aud" : "sts.amazonaws.com",
            "${local.oidc_hostpath}:sub" : "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name        = var.efs_csi_role_name != "" ? var.efs_csi_role_name : "${var.cluster_name}-efs-csi-role"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# Look up latest compatible add-on versions for this cluster
# Use var.k8s_version instead of aws_eks_cluster.cluster.version to avoid
# deferred data source reads when the cluster has pending changes
data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.k8s_version
  most_recent        = true
}

data "aws_eks_addon_version" "efs_csi" {
  addon_name         = "aws-efs-csi-driver"
  kubernetes_version = var.k8s_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  count              = var.manage_kube_proxy_addon ? 1 : 0
  addon_name         = "kube-proxy"
  kubernetes_version = var.k8s_version
  most_recent        = true
}

# EKS managed add-ons — always use the latest compatible version
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  tags = {
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags, tags_all, addon_version]
  }
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = "aws-efs-csi-driver"
  addon_version            = data.aws_eks_addon_version.efs_csi.version
  service_account_role_arn = aws_iam_role.efs_csi.arn

  # Override default resource allocations — the upstream defaults (200m/256Mi per
  # controller container) are far too generous for a small cluster.
  # Note: sidecar resources are not configurable via the EKS addon schema.
  configuration_values = jsonencode({
    controller = {
      resources = {
        requests = { cpu = "10m", memory = "40Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
    }
  })

  tags = {
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  depends_on = [aws_iam_role_policy_attachment.efs_csi]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags, tags_all, configuration_values, pod_identity_association, addon_version]
  }
}

resource "aws_eks_addon" "kube_proxy" {
  count         = var.manage_kube_proxy_addon ? 1 : 0
  cluster_name  = aws_eks_cluster.cluster.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy[0].version

  tags = {
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags, tags_all]
  }
}

