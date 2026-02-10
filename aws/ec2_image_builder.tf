# ==============================================================================
# S3 BUCKET FOR IMAGE BUILDER LOGS
# ==============================================================================
# This bucket stores logs generated during the EC2 Image Builder build process
resource "aws_s3_bucket" "imagebuilder_log_bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-imagebuilder-logs"

  tags = {
    Name = "ImageBuilder Log Bucket"
  }
}

# ==============================================================================
# IAM ROLE FOR EC2 IMAGE BUILDER INSTANCES
# ==============================================================================
# This role is assumed by EC2 instances during the image building process
# It grants permissions needed to build images and write logs
resource "aws_iam_role" "instance_role" {
  name        = "ImageBuilderInstanceRole"
  path        = "/executionServiceEC2Role/"
  description = "Role to be used by instance during image build"

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
    Name = "ImageBuilderInstanceRole"
  }
}

# Attach AWS managed policy for SSM (allows remote access and management)
resource "aws_iam_role_policy_attachment" "instance_role_ssm" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for Image Builder (provides permissions to build images)
resource "aws_iam_role_policy_attachment" "instance_role_imagebuilder" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

# ==============================================================================
# INLINE POLICY FOR S3 LOGGING
# ==============================================================================
# Allows the Image Builder instance to write logs to the S3 bucket
resource "aws_iam_role_policy" "instance_role_logging_policy" {
  name = "ImageBuilderLogBucketPolicy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.imagebuilder_log_bucket.arn}/*"
        ]
      }
    ]
  })
}

# ==============================================================================
# INSTANCE PROFILE
# ==============================================================================
# Instance profile is required to attach the IAM role to EC2 instances
resource "aws_iam_instance_profile" "instance_profile" {
  name = "ImageBuilderInstanceProfile"
  path = "/executionServiceEC2Role/"
  role = aws_iam_role.instance_role.name
}

# ==============================================================================
# IMAGE BUILDER INFRASTRUCTURE CONFIGURATION
# ==============================================================================
# Defines the infrastructure settings for building images:
# - Instance types to use during build
# - Subnet and security group for build instances
# - S3 bucket for storing logs
# - Whether to terminate instances on build failure
resource "aws_imagebuilder_infrastructure_configuration" "sift_infrastructure" {
  name                          = "UbuntuServer20-Image-Infrastructure-Configuration"
  instance_profile_name         = aws_iam_instance_profile.instance_profile.name
  instance_types                = ["t2.medium", "t2.large", "t2.xlarge", "t3.medium", "t3.large", "t3.xlarge"]
  subnet_id                     = aws_subnet.maintenance_private_subnet.id
  security_group_ids            = [aws_security_group.security_group_private.id]
  terminate_instance_on_failure = false

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.imagebuilder_log_bucket.id
      s3_key_prefix  = "imagebuilder-logs"
    }
  }

  tags = {
    Name = "SIFT Infrastructure Configuration"
  }
}

# ==============================================================================
# CUSTOM IMAGE BUILDER COMPONENT - INSTALL SIFT
# ==============================================================================
# This component defines the steps to install SIFT (SANS Investigative Forensic Toolkit)
# SIFT is a collection of forensic tools for incident response and digital forensics
resource "aws_imagebuilder_component" "install_sift" {
  name        = "install-SIFT"
  platform    = "Linux"
  version     = "1.0.0"
  description = "Installs SIFT (https://github.com/teamdfir/sift) from scratch"

  # The data field contains the YAML document that defines the build steps
  data = <<-EOT
    name: InstallSIFTDocument
    description: This is a EC2 Image Builder document to install SIFT on Ubuntu 20 LTS
    schemaVersion: 1.0

    phases:
      - name: build
        steps:
          - name: InstallSIFT
            action: ExecuteBash
            timeoutSeconds: -1
            inputs:
              commands:
                - |
                  wget https://github.com/ekristen/cast/releases/download/v0.14.0/cast_v0.14.0_linux_amd64.deb
                  sudo dpkg -i cast_v0.14.0_linux_amd64.deb
                  sudo apt update && sudo apt upgrade -y
                  sudo cast install --mode=server teamdfir/sift-saltstack
  EOT

  tags = {
    Name = "Install SIFT Component"
  }
}

# ==============================================================================
# IMAGE BUILDER RECIPE
# ==============================================================================
# Defines what goes into the AMI:
# - Parent/base image (Ubuntu 22 LTS)
# - Storage configuration (30GB root volume)
# - Components to install (AWS managed + custom SIFT component)
resource "aws_imagebuilder_image_recipe" "sift_image_recipe" {
  name         = "SIFTImageRecipe"
  version      = "1.0.0"
  parent_image = "arn:${data.aws_partition.current.partition}:imagebuilder:${data.aws_region.current.name}:aws:image/ubuntu-server-22-lts-x86/x.x.x"

  # Configure the root volume size and type
  block_device_mapping {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  # Components are executed in order during the image build process
  # AWS managed components
  component {
    component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/update-linux/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/amazon-cloudwatch-agent-linux/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/aws-cli-version-2-linux/x.x.x"
  }

  # Custom SIFT installation component
  component {
    component_arn = aws_imagebuilder_component.install_sift.arn
  }

  # Reboot and test components (ensure system stability after installation)
  component {
    component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/reboot-test-linux/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/reboot-linux/x.x.x"
  }

  tags = {
    Name = "SIFT Image Recipe"
  }
}

# ==============================================================================
# DISTRIBUTION CONFIGURATION
# ==============================================================================
# Defines how and where to distribute the built AMI
# Can configure multiple regions, accounts, and AMI naming patterns
resource "aws_imagebuilder_distribution_configuration" "sift_distribution" {
  name        = "SIFT-distribution-configuration"
  description = "Forensic image distribution"

  distribution {
    region = data.aws_region.current.name

    ami_distribution_configuration {
      name        = "ami-forensic-image {{ imagebuilder:buildDate }}"
      description = "Forensics golden image"

      # Optional: Configure AMI launch permissions
      # launch_permission {
      #   user_ids = ["123456789012"]
      # }
    }
  }

  tags = {
    Name = "SIFT Distribution Configuration"
  }
}

# ==============================================================================
# IMAGE BUILDER IMAGE
# ==============================================================================
# Triggers the actual image build process
# This resource orchestrates the infrastructure, recipe, and distribution configs
resource "aws_imagebuilder_image" "sift_image" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.sift_image_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.sift_infrastructure.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.sift_distribution.arn

  tags = {
    Name = "SIFT Image"
  }
}

# ==============================================================================
# SSM PARAMETER - STORE AMI ID
# ==============================================================================
# Stores the resulting AMI ID in SSM Parameter Store for easy reference
# Other CloudFormation/Terraform stacks can reference this parameter to launch instances
resource "aws_ssm_parameter" "sift_image_parameter" {
  name        = "/Test/Images/SIFTImage"
  description = "Image Id for Ubuntu Server 20 With latest SIFT"
  type        = "String"
  value       = one(one(aws_imagebuilder_image.sift_image.output_resources).amis).image


  tags = {
    Name = "SIFT Image AMI ID"
  }

  depends_on = [aws_imagebuilder_image.sift_image]
}