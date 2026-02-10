# ==============================================================================
# MAINTENANCE VPC
# ==============================================================================
# This VPC is used for maintenance and management operations
# It has both public and private subnets with internet access via NAT Gateway
resource "aws_vpc" "maintenance_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MaintenanceVPC"
  }
}


# Maintenance VPC Flow Logs
resource "aws_flow_log" "maintenance_flow_logs" {
  log_destination      = aws_s3_bucket.s3_vpc_flowlogs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.maintenance_vpc.id

  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${pkt-src-aws-service} $${flow-direction}"

  tags = {
    Name = "VpcFlowLogs-MaintenanceVPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.maintenance_vpc.id

  tags = {
    Name = "maintenance-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  #domain = "vpc"

  tags = {
    Name = "nat-gateway-eip"
  }

  depends_on = [aws_internet_gateway.internet_gateway]
}

# Public Subnet
resource "aws_subnet" "maintenance_public_subnet" {
  vpc_id            = aws_vpc.maintenance_vpc.id
  cidr_block        = "10.0.0.0/17"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Maintenance-Public"
  }
}

# Private Subnet
resource "aws_subnet" "maintenance_private_subnet" {
  vpc_id            = aws_vpc.maintenance_vpc.id
  cidr_block        = "10.0.128.0/17"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Maintenance-Private"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.maintenance_public_subnet.id

  tags = {
    Name = "maintenance-nat-gateway"
  }

  depends_on = [aws_internet_gateway.internet_gateway]
}

# Public Security Group
resource "aws_security_group" "security_group_public" {
  name        = "maintenance-public-sg"
  description = "Public security group with just egress rule"
  vpc_id      = aws_vpc.maintenance_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "maintenance-public-sg"
  }
}

# Private Security Group
resource "aws_security_group" "security_group_private" {
  name        = "maintenance-private-sg"
  description = "Private security group"
  vpc_id      = aws_vpc.maintenance_vpc.id

  tags = {
    Name = "maintenance-private-sg"
  }
}

# Private Security Group - Ingress Rule (self-referencing)
resource "aws_security_group_rule" "security_group_private_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.security_group_private.id
  security_group_id        = aws_security_group.security_group_private.id
}

# Private Security Group - Egress Rule
resource "aws_security_group_rule" "security_group_private_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group_private.id
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.maintenance_vpc.id

  tags = {
    Name = "Public Route"
  }
}

# Public Route - Internet Gateway
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

# Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.maintenance_vpc.id

  tags = {
    Name = "Private Route"
  }
}

# Private Route - NAT Gateway
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# Public Subnet Route Table Association
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.maintenance_public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Subnet Route Table Association
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.maintenance_private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}