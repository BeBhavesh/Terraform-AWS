# =====================================================
# variables.tf
# All input variables used across this project are defined here.
# Default values are provided so the project can run "out of the box",
# but you should override important ones in terraform.tfvars
# =====================================================

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project, used as a prefix for resource names and tags"
  type        = string
  default     = "devops-fresher-project"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging). Kept simple for this project."
  type        = string
  default     = "dev"
}

# -----------------------------------------------------
# Networking Variables
# -----------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (hosts EC2, NAT Gateway)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (hosts EKS worker nodes)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability Zone to launch subnets in (single AZ, kept simple for a fresher project)"
  type        = string
  default     = "us-east-1a"
}

# -----------------------------------------------------
# EC2 Variables
# -----------------------------------------------------

variable "ec2_instance_type" {
  description = "Instance type for the EC2 server"
  type        = string
  default     = "t2.micro" # Free-tier eligible
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 instance. Default is Amazon Linux 2023 in us-east-1. Change this if you use a different region."
  type        = string
  default     = "ami-0c101f26f147fa7fd" # Amazon Linux 2023 (us-east-1) - verify/update before use
}

variable "key_pair_name" {
  description = "Name of an EXISTING EC2 Key Pair (in your AWS account) used to SSH into the instance"
  type        = string
  default     = "" # You must create a key pair in AWS console/CLI first and put its name here
}

variable "my_ip_cidr" {
  description = "Your local IP address in CIDR format (e.g., 1.2.3.4/32), used to restrict SSH access to only you"
  type        = string
  default     = "0.0.0.0/0" # WARNING: default allows SSH from anywhere. Change this in terraform.tfvars for real use!
}

# -----------------------------------------------------
# S3 Variables
# -----------------------------------------------------

variable "s3_bucket_name" {
  description = "Globally unique name for the S3 bucket. S3 bucket names must be unique across ALL AWS accounts."
  type        = string
  default     = "devops-fresher-project-bucket-change-me-12345"
}

# -----------------------------------------------------
# EKS Variables
# -----------------------------------------------------

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "devops-fresher-eks-cluster"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type used for EKS worker nodes"
  type        = string
  default     = "t3.medium" # Minimum recommended size for EKS worker nodes
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes in the EKS node group"
  type        = number
  default     = 2
}
