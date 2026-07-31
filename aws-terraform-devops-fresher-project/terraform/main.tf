# =====================================================
# main.tf
# This is the core file where all AWS resources are defined.

# =====================================================


# -----------------------------------------------------
# 1. VPC (Virtual Private Cloud)
# Our own isolated network inside AWS.
# -----------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Required for EKS and internal DNS resolution
  enable_dns_hostnames = true # Required for EKS worker nodes

  tags = {
    Name = "${var.project_name}-vpc"
  }
}


# -----------------------------------------------------
# 2. Public Subnet
# Resources here (EC2, NAT Gateway) can have public IPs
# and talk directly to the internet through the Internet Gateway.
# -----------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = var.public_subnet_cidr
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true # Auto-assign public IP to instances launched here

  tags = {
    Name                                          = "${var.project_name}-public-subnet"
    "kubernetes.io/role/elb"                      = "1" # Hints EKS this subnet can host public load balancers
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}


# -----------------------------------------------------
# 3. Private Subnet
# Resources here (EKS worker nodes) have NO direct public IP.
# They reach the internet only via the NAT Gateway.
# -----------------------------------------------------
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name                                          = "${var.project_name}-private-subnet"
    "kubernetes.io/role/internal-elb"             = "1" # Hints EKS this subnet can host internal load balancers
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}


# -----------------------------------------------------
# 4. Internet Gateway
# Allows resources in the PUBLIC subnet to reach the internet.
# -----------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}


# -----------------------------------------------------
# 5. Elastic IP for NAT Gateway
# NAT Gateway needs a fixed public IP address.
# -----------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  # NAT EIP depends on the Internet Gateway being attached first
  depends_on = [aws_internet_gateway.main]
}


# -----------------------------------------------------
# 6. NAT Gateway
# Lives in the PUBLIC subnet. Allows resources in the PRIVATE
# subnet (like EKS nodes) to reach the internet (e.g., to pull
# container images) WITHOUT being directly exposed to it.
# -----------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}


# -----------------------------------------------------
# 7. Public Route Table
# Routes all outbound traffic (0.0.0.0/0) to the Internet Gateway.
# -----------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# -----------------------------------------------------
# 8. Private Route Table
# Routes all outbound traffic (0.0.0.0/0) to the NAT Gateway
# instead of the Internet Gateway (keeps private resources hidden).
# -----------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate private route table with the private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


# -----------------------------------------------------
# 9. Security Group - EC2
# Controls what traffic is allowed in/out of the EC2 instance.
# -----------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH and HTTP access to the EC2 instance"
  vpc_id      = aws_vpc.main.id

  # Allow SSH only from your IP (set via var.my_ip_cidr)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Allow HTTP access from anywhere (for a simple web server demo)
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (default AWS behavior, made explicit here)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}


# -----------------------------------------------------
# 10. IAM Role + Instance Profile - EC2
# Lets the EC2 instance access AWS services (S3, in this case)
# WITHOUT hardcoding AWS access keys on the instance.
# -----------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  # Trust policy: allows the EC2 service to "assume" this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# Attach AWS-managed policy so EC2 can read from S3
resource "aws_iam_role_policy_attachment" "ec2_s3_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Instance profile wraps the IAM role so it can be attached to an EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}


# -----------------------------------------------------
# 11. EC2 Instance
# A simple server running in the PUBLIC subnet.
# -----------------------------------------------------
resource "aws_instance" "app_server" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  # Simple startup script that installs and starts a basic web server
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from ${var.project_name} EC2 instance</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "${var.project_name}-ec2-server"
  }
}


# -----------------------------------------------------
# 12. S3 Bucket
# Simple object storage bucket, kept private by default.
# -----------------------------------------------------
resource "aws_s3_bucket" "app_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "${var.project_name}-s3-bucket"
  }
}

# Block all public access to the bucket (best practice / secure default)
resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning so accidentally deleted/overwritten files can be recovered
resource "aws_s3_bucket_versioning" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}


# -----------------------------------------------------
# 13. IAM Role - EKS Cluster (Control Plane)
# Allows the EKS service itself to manage AWS resources
# (ENIs, load balancers, etc.) on your behalf.
# -----------------------------------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# -----------------------------------------------------
# 14. IAM Role - EKS Node Group (Worker Nodes)
# Allows the worker node EC2 instances to join the cluster,
# pull container images, and manage networking.
# -----------------------------------------------------
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eks-node-role"
  }
}

# Required policy: allows nodes to register with the EKS cluster
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Required policy: allows nodes to manage networking (VPC CNI plugin)
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Required policy: allows nodes to pull container images from ECR
resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# -----------------------------------------------------
# 15. EKS Cluster (Control Plane)
# The managed Kubernetes control plane. AWS manages the
# master nodes for us - we only manage worker nodes.
# -----------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids = [
      aws_subnet.public.id,
      aws_subnet.private.id
    ]
    endpoint_public_access  = true # Lets you run kubectl from your laptop
    endpoint_private_access = true # Lets worker nodes talk to the API server privately
  }

  # Cluster creation requires these IAM policies to be attached first
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {# Kept intentionally simple (no modules) so a fresher can read
# top-to-bottom and understand exactly what gets created.
    Name = var.eks_cluster_name
  }
}


# -----------------------------------------------------
# 16. EKS Managed Node Group (Worker Nodes)
# The actual EC2 instances that run your Kubernetes workloads.
# Placed in the PRIVATE subnet for better security.
# "Managed" means AWS handles patching/updating of these nodes for us.
# -----------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private.id]
  instance_types  = [var.eks_node_instance_type]

  scaling_config {
    desired_size = var.eks_node_desired_size
    min_size     = var.eks_node_min_size
    max_size     = var.eks_node_max_size
  }

  # Node group creation requires these IAM policies to be attached first
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only
  ]

  tags = {
    Name = "${var.project_name}-eks-node-group"
  }
}
