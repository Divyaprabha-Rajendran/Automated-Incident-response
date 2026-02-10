terraform {
  backend "s3" {
    bucket         = "terraform-state-forensics"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Provider Configuration
provider "aws" {
  region = "us-east-1"
}

