# =====================================================
# providers.tf
# This file tells Terraform:
#   1. Which Terraform version we need
#   2. Which providers (plugins) we need (here: AWS)
#   3. How to connect to AWS (region)
# =====================================================

terraform {
  required_version = ">= 1.5.0" # Minimum Terraform CLI version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use AWS provider version 5.x
    }
  }

  # NOTE (for learning purposes):
  # In real projects, state is usually stored remotely (e.g., S3 + DynamoDB)
  # so multiple people can collaborate safely.
  #
  # backend "s3" {
  #   bucket = "my-terraform-state-bucket"
  #   key    = "devops-fresher-project/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region # Region is set via variables.tf / terraform.tfvars

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
