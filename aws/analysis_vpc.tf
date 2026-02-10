# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Analysis VPC
resource "aws_vpc" "analysis_vpc" {
  cidr_block           = "10.66.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "AnalysisVPC"
  }
}

# VPC Flow Logs
resource "aws_flow_log" "analysis_flow_logs" {
  log_destination      = aws_s3_bucket.s3_vpc_flowlogs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.analysis_vpc.id

  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${pkt-src-aws-service} $${flow-direction}"

  tags = {
    Name = "VpcFlowLogs-AnalysisVPC"
  }
}

# Analysis Subnets
resource "aws_subnet" "analysis_subnet1" {
  vpc_id                  = aws_vpc.analysis_vpc.id
  cidr_block              = "10.66.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "analysis-subnet1"
  }
}

resource "aws_subnet" "analysis_subnet2" {
  vpc_id                  = aws_vpc.analysis_vpc.id
  cidr_block              = "10.66.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "analysis-subnet2"
  }
}

resource "aws_subnet" "analysis_subnet3" {
  vpc_id                  = aws_vpc.analysis_vpc.id
  cidr_block              = "10.66.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false

  tags = {
    Name = "analysis-subnet3"
  }
}

# Route Table
resource "aws_route_table" "analysis_route_table" {
  vpc_id = aws_vpc.analysis_vpc.id

  tags = {
    Name = "Analysis VPC Route Table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "analysis_subnet1" {
  subnet_id      = aws_subnet.analysis_subnet1.id
  route_table_id = aws_route_table.analysis_route_table.id
}

resource "aws_route_table_association" "analysis_subnet2" {
  subnet_id      = aws_subnet.analysis_subnet2.id
  route_table_id = aws_route_table.analysis_route_table.id
}

resource "aws_route_table_association" "analysis_subnet3" {
  subnet_id      = aws_subnet.analysis_subnet3.id
  route_table_id = aws_route_table.analysis_route_table.id
}

# Security Group for IR Instances
resource "aws_security_group" "analysis_instance_sg" {
  name        = "ir-instance-sg"
  description = "Security Group for IR Instance"
  vpc_id      = aws_vpc.analysis_vpc.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ir-instance-sg"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "analysis_endpoint_sg" {
  name        = "ir-vpce-sg"
  description = "Security Group for IR VPC Endpoints"
  vpc_id      = aws_vpc.analysis_vpc.id

  ingress {
    description     = "HTTPS from IR instances"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.analysis_instance_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ir-vpce-sg"
  }
}

# Data source for current region
data "aws_region" "current" {}

#data "aws_partition" "current" {}

# S3 Gateway VPC Endpoint
resource "aws_vpc_endpoint" "analysis_s3_endpoint" {
  vpc_id            = aws_vpc.analysis_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.analysis_route_table.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:CreateMultipartUpload",
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = [
          aws_s3_bucket.s3_ir_artifact_bucket.arn,
          "${aws_s3_bucket.s3_ir_artifact_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "analysis-s3-endpoint"
  }
}

# SSM VPC Endpoint
resource "aws_vpc_endpoint" "analysis_ssm_endpoint" {
  vpc_id              = aws_vpc.analysis_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [
    aws_subnet.analysis_subnet1.id,
    aws_subnet.analysis_subnet2.id,
    aws_subnet.analysis_subnet3.id
  ]
  security_group_ids  = [aws_security_group.analysis_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "analysis-ssm-endpoint"
  }
}

# SSM Messages VPC Endpoint
resource "aws_vpc_endpoint" "analysis_ssmmessages_endpoint" {
  vpc_id              = aws_vpc.analysis_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [
    aws_subnet.analysis_subnet1.id,
    aws_subnet.analysis_subnet2.id,
    aws_subnet.analysis_subnet3.id
  ]
  security_group_ids  = [aws_security_group.analysis_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "analysis-ssmmessages-endpoint"
  }
}

# EC2 Messages VPC Endpoint
resource "aws_vpc_endpoint" "analysis_ec2messages_endpoint" {
  vpc_id              = aws_vpc.analysis_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [
    aws_subnet.analysis_subnet1.id,
    aws_subnet.analysis_subnet2.id,
    aws_subnet.analysis_subnet3.id
  ]
  security_group_ids  = [aws_security_group.analysis_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "analysis-ec2messages-endpoint"
  }
}

# IAM Role for EC2 instances with S3 Read-Only access
resource "aws_iam_role" "analysis_ec2_instance_role_s3_readonly" {
  name        = "AnalysisEC2InstanceRoleS3ReadOnly"
  description = "Role to be used by SOC for accessing the instances through SSM Session manager and S3 read-only access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "AnalysisEC2InstanceRoleS3ReadOnly"
  }
}

# Attach AWS managed policies for Read-Only role
resource "aws_iam_role_policy_attachment" "analysis_ec2_ssm_readonly" {
  role       = aws_iam_role.analysis_ec2_instance_role_s3_readonly.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "analysis_ec2_s3_readonly" {
  role       = aws_iam_role.analysis_ec2_instance_role_s3_readonly.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Instance Profile for S3 Read-Only Role
resource "aws_iam_instance_profile" "analysis_ec2_instance_profile_s3_readonly" {
  name = "AnalysisEC2InstanceProfileS3ReadOnly"
  role = aws_iam_role.analysis_ec2_instance_role_s3_readonly.name
}

# IAM Role for EC2 instances with S3 Read-Write access
resource "aws_iam_role" "analysis_ec2_instance_role_s3_readwrite" {
  name        = "AnalysisEC2InstanceRoleS3ReadWrite"
  description = "Role to be used by SOC for accessing the instances through SSM Session manager and S3 read-write access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "S3ReadWrite"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:*Object*",
            "s3:GetBucketLocation"
          ]
          Resource = [
            aws_s3_bucket.s3_ir_artifact_bucket.arn,
            "${aws_s3_bucket.s3_ir_artifact_bucket.arn}/*"
          ]
        }
      ]
    })
  }

  tags = {
    Name = "AnalysisEC2InstanceRoleS3ReadWrite"
  }
}

# Attach SSM managed policy for Read-Write role
resource "aws_iam_role_policy_attachment" "analysis_ec2_ssm_readwrite" {
  role       = aws_iam_role.analysis_ec2_instance_role_s3_readwrite.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile for S3 Read-Write Role
resource "aws_iam_instance_profile" "analysis_ec2_instance_profile_s3_readwrite" {
  name = "AnalysisEC2InstanceProfileS3ReadWrite"
  role = aws_iam_role.analysis_ec2_instance_role_s3_readwrite.name
}