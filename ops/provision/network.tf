resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${terraform.workspace}-vpc"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  # Imported clusters (e.g. r2-bl-ethos) have existing VPC CIDR; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block]
  }
}

# Public subnets for load balancers, NAT Gateway, and EKS
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${terraform.workspace}-public-subnet-az1"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                   = "1"
  }

  # Imported clusters: keep existing subnet CIDR/AZ; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block, availability_zone, map_public_ip_on_launch, vpc_id]
  }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${terraform.workspace}-public-subnet-az2"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                   = "1"
  }

  # Imported clusters: keep existing subnet CIDR/AZ; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block, availability_zone, map_public_ip_on_launch, vpc_id]
  }
}

resource "aws_subnet" "public_az3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${terraform.workspace}-public-subnet-az3"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                   = "1"
  }

  # Imported clusters: keep existing subnet CIDR/AZ; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block, availability_zone, map_public_ip_on_launch, vpc_id]
  }
}

# Private subnets for EKS nodes
resource "aws_subnet" "az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false  # Private!
  
  tags = {
    Name        = "${terraform.workspace}-private-subnet-az1"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }

  # Imported clusters: keep existing subnet CIDR/AZ; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block, availability_zone, map_public_ip_on_launch, vpc_id]
  }
}

resource "aws_subnet" "az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false  # Private!
  
  tags = {
    Name        = "${terraform.workspace}-private-subnet-az2"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }

  # Imported clusters: keep existing subnet CIDR/AZ; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block, availability_zone, map_public_ip_on_launch, vpc_id]
  }
}

resource "aws_subnet" "az3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = false  # Private!
  
  tags = {
    Name        = "${terraform.workspace}-private-subnet-az3"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }

  # Imported clusters: keep existing subnet CIDR/AZ; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, cidr_block, availability_zone, map_public_ip_on_launch, vpc_id]
  }
}

# Internet Gateway for public egress
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${terraform.workspace}-igw"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Single NAT Gateway in public AZ2
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${terraform.workspace}-nat-eip"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  lifecycle {
    ignore_changes = [tags, tags_all]
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az2.id

  tags = {
    Name        = "${terraform.workspace}-nat"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  # When importing: NAT may be in a different AZ than our template; avoid replace
  lifecycle {
    ignore_changes = [subnet_id, tags, tags_all]
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public route table with default route to Internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${terraform.workspace}-public-rt"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  # Imported: keep existing route table; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, vpc_id]
  }
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.igw.id
}

# Single private route table; all private subnets use one NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${terraform.workspace}-private-rt"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  }

  # Imported: keep existing route table; do not replace
  lifecycle {
    ignore_changes = [tags, tags_all, vpc_id]
  }
}

# Private default route: IGW for now (revert to NAT later with nat_gateway_id if desired).
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public subnets to public route table
resource "aws_route_table_association" "public_az1_assoc" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2_assoc" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az3_assoc" {
  subnet_id      = aws_subnet.public_az3.id
  route_table_id = aws_route_table.public.id
}

# Associate all private subnets to the single private route table
resource "aws_route_table_association" "az1_assoc" {
  subnet_id      = aws_subnet.az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "az2_assoc" {
  subnet_id      = aws_subnet.az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "az3_assoc" {
  subnet_id      = aws_subnet.az3.id
  route_table_id = aws_route_table.private.id
}
