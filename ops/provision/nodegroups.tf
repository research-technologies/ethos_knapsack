resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.cluster_name}-eks-node-"
  instance_type = var.node_instance_type

  # Root volume size (ephemeral storage). EKS AL2 AMI uses /dev/xvda. Omit to use AMI default (~20 GiB).
  dynamic "block_device_mappings" {
    for_each = var.node_root_volume_size != null ? [1] : []
    content {
      device_name = "/dev/xvda"
      ebs {
        volume_size           = var.node_root_volume_size
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
      }
    }
  }

  # EKS bootstrap + GitHub keys + Site24x7 (managed by Terraform; matches current AWS LT when in sync).
  user_data = base64encode(
    templatefile("${path.module}/user_data.txt", {
      cluster_name     = aws_eks_cluster.cluster.name
      cluster_endpoint = aws_eks_cluster.cluster.endpoint
      cluster_ca       = aws_eks_cluster.cluster.certificate_authority[0].data
      github_users     = join("\n", [for user in var.admin_github_users : "curl -fsSL https://github.com/${user}.keys >> /home/ec2-user/.ssh/authorized_keys || true"])
      enable_site24x7  = var.enable_site24x7
      site24x7_key     = var.site24x7_key
      site24x7_group   = var.site24x7_group
    })
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-node"
      ManagedBy   = "terraform"
      Environment = terraform.workspace
      Cluster     = aws_eks_cluster.cluster.name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.cluster_name}-node-volume"
      ManagedBy   = "terraform"
      Environment = terraform.workspace
    }
  }

  # When importing: existing LT (e.g. Rancher-managed) has different name, instance_type; avoid replace.
  # user_data is managed — remove from ignore_changes so Terraform can update it.
  lifecycle {
    ignore_changes = [
      name_prefix,
      name,
      instance_type,
      block_device_mappings,
      tag_specifications,
      key_name,
      tags,
      tags_all,
    ]
  }
}

resource "aws_eks_node_group" "default" {
  version               = var.k8s_version
  force_update_version  = false  # Respect PodDisruptionBudgets during updates
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = var.node_group_name != "" ? var.node_group_name : "${terraform.workspace}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.public_az1.id, aws_subnet.public_az2.id, aws_subnet.public_az3.id]

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  # Replace nodes one at a time to ensure StatefulSet pods can always
  # find a node in their EBS volume's AZ
  update_config {
    max_unavailable = 1
  }

  # Launch template (use $Latest so instance_type, root volume, user_data from tfvars apply to new nodes)
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  lifecycle {
    # Provider stores resolved version; ignore to avoid drift. When importing, keep existing LT reference.
    ignore_changes = [
      launch_template[0].id,
      launch_template[0].name,
      launch_template[0].version,
      force_update_version,
      labels,
      tags,
      tags_all,
    ]
  }

  # Node labels
  labels = {
    "node.kubernetes.io/instance-type" = var.node_instance_type
    "Environment"                       = terraform.workspace
    "ManagedBy"                         = "terraform"
  }

  tags = {
    Environment = terraform.workspace
    Cluster     = aws_eks_cluster.cluster.name
    ManagedBy   = "terraform"
  }

  # If apply fails with "Nodegroup cannot be updated as it is currently not in Active State",
  # wait for the node group to finish its current operation (e.g. scaling) then run apply again.

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
  ]
}
