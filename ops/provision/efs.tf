# EFS integration for shared file storage
# EFS CSI driver is configured in addons.tf with IRSA
#
# Two modes (set in tfvars):
# - efs_file_system_id = "" → Terraform creates a new EFS + SG + mount targets (aws_efs_file_system.efs).
# - efs_file_system_id = "fs-xxxx" → Use existing EFS only; import into state as aws_efs_file_system.efs_imported.
#   Run the import script with EFS_ID set, or: tofu import 'aws_efs_file_system.efs_imported[0]' fs-xxxx
#   Mount targets and SG are not managed by Terraform in this mode.

locals {
  efs_create_new = var.efs_file_system_id == ""
  efs_use_existing = var.efs_file_system_id != ""
}

# Security group for EFS mount targets (only when we create EFS and don't provide an existing SG)
resource "aws_security_group" "ingress-efs" {
  count = local.efs_create_new && var.efs_security_group_id == "" ? 1 : 0

  name        = "${var.cluster_name}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.cluster_name}-efs-sg"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs" {
  count = local.efs_create_new && var.efs_security_group_id == "" ? 1 : 0

  security_group_id = aws_security_group.ingress-efs[0].id
  cidr_ipv4         = aws_vpc.main.cidr_block
  description       = "Allow NFS traffic from VPC"
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "efs_egress" {
  count = local.efs_create_new && var.efs_security_group_id == "" ? 1 : 0

  security_group_id = aws_security_group.ingress-efs[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "efs_egress_6" {
  count = local.efs_create_new && var.efs_security_group_id == "" ? 1 : 0

  security_group_id = aws_security_group.ingress-efs[0].id
  cidr_ipv6         = "::/0"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
}

locals {
  efs_mount_target_sg_id = local.efs_create_new ? (var.efs_security_group_id != "" ? var.efs_security_group_id : aws_security_group.ingress-efs[0].id) : null
}

# EFS created by Terraform (only when efs_file_system_id is not set)
resource "aws_efs_file_system" "efs" {
  count = local.efs_create_new ? 1 : 0

  creation_token   = var.efs_creation_token != "" ? var.efs_creation_token : "${var.cluster_name}EFS"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name        = var.efs_name != "" ? var.efs_name : "${var.cluster_name}EFS"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags, tags_all]
  }
}

# Existing EFS imported into state (when efs_file_system_id is set in tfvars).
# Import with: tofu import 'aws_efs_file_system.efs_imported[0]' <fs-id>
# Or run scripts/import-eks-cluster.sh with EFS_ID set in your env.
resource "aws_efs_file_system" "efs_imported" {
  count = local.efs_use_existing ? 1 : 0

  lifecycle {
    ignore_changes = [tags, tags_all, creation_token, performance_mode, throughput_mode, encrypted, lifecycle_policy]
  }
}

# Mount targets only when we create the EFS (not when using existing)
resource "aws_efs_mount_target" "efs-mt" {
  for_each = local.efs_create_new ? {
    az1 = aws_subnet.az1.id
    az2 = aws_subnet.az2.id
    az3 = aws_subnet.az3.id
  } : {}

  file_system_id  = aws_efs_file_system.efs[0].id
  security_groups = [local.efs_mount_target_sg_id]
  subnet_id       = each.value

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  efs_id       = local.efs_use_existing ? aws_efs_file_system.efs_imported[0].id : aws_efs_file_system.efs[0].id
  efs_dns_name = local.efs_use_existing ? aws_efs_file_system.efs_imported[0].dns_name : aws_efs_file_system.efs[0].dns_name
}

output "efs_file_system_dns_name" {
  description = "DNS name of the EFS file system"
  value       = local.efs_dns_name
}

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = local.efs_id
}

# Note: EFS CSI driver permissions are handled via IRSA in addons.tf
# The EFS CSI driver service account uses the role defined there
# No additional IAM policy attachment to node role is needed
