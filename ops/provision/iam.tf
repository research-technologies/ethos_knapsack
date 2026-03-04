resource "aws_iam_role" "cluster" {
  name = var.cluster_iam_role_name != "" ? var.cluster_iam_role_name : "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = ["sts:AssumeRole", "sts:TagSession"]
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
      }
    ]
  })

  tags = {
    Name        = var.cluster_iam_role_name != "" ? var.cluster_iam_role_name : "${var.cluster_name}-eks-cluster-role"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  # Imported: keep permissions_boundary (e.g. CrayonBoundary) if set in AWS
  lifecycle {
    ignore_changes = [assume_role_policy, tags, tags_all, permissions_boundary]
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node" {
  name = var.node_iam_role_name != "" ? var.node_iam_role_name : "${var.cluster_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = var.node_iam_role_name != "" ? var.node_iam_role_name : "${var.cluster_name}-eks-node-role"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    ignore_changes = [assume_role_policy, tags, tags_all]
  }
}

# Attach the required policies
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
