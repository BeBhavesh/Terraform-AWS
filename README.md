# AWS DevOps Fresher Project — Terraform Infrastructure

A beginner-friendly, hands-on DevOps portfolio project that provisions a
small, realistic AWS environment using **Terraform**: a VPC with public
and private subnets, an EC2 web server, an S3 bucket, and an Amazon EKS
(Kubernetes) cluster.

> This is a **learning / portfolio project**, built to demonstrate core
> Terraform and AWS networking concepts clearly — it is **not** a
> production-grade or enterprise-scale setup. Everything is kept simple
> and readable on purpose.

---

## 📌 Project Overview

This project uses Infrastructure as Code (Terraform) to create:

| # | Resource | Purpose |
|---|----------|---------|
| 1 | VPC | Isolated private network in AWS |
| 2 | Public Subnet | Hosts EC2 instance + NAT Gateway |
| 3 | Private Subnet | Hosts EKS worker nodes |
| 4 | Internet Gateway | Gives the public subnet internet access |
| 5 | NAT Gateway | Gives the private subnet outbound-only internet access |
| 6 | Route Tables | Direct traffic from each subnet to the correct gateway |
| 7 | Security Group | Firewall rules for the EC2 instance |
| 8 | IAM Roles | Secure, key-less permissions for EC2, EKS cluster, and EKS nodes |
| 9 | EC2 Instance | A simple web server (Amazon Linux + Apache) |
| 10 | S3 Bucket | Private, versioned object storage |
| 11 | Amazon EKS Cluster | Managed Kubernetes cluster with a worker node group |

See [`docs/architecture.md`](docs/architecture.md) for a full ASCII
architecture diagram and traffic-flow explanation.

---

## 📁 Folder Structure

```
aws-terraform-devops-fresher-project/
├── README.md                        # You are here
├── LICENSE                          # MIT License
├── .gitignore                       # Ignores state files, secrets, etc.
│
├── terraform/
│   ├── providers.tf                 # Terraform + AWS provider setup
│   ├── variables.tf                 # All input variables (with comments)
│   ├── main.tf                      # All AWS resources (VPC → EKS)
│   ├── outputs.tf                   # Useful values printed after apply
│   └── terraform.tfvars.example     # Sample variable values (copy this)
│
└── docs/
    ├── architecture.md              # ASCII architecture diagram
    ├── troubleshooting.md           # Common errors & fixes
    └── interview-questions.md       # Q&A to prep for interviews
```

---

## ✅ Prerequisites

Before you begin, make sure you have:

1. **An AWS account** (free tier is fine, but EKS + NAT Gateway are
   **not** free — see the cost warning below).
2. **AWS CLI** installed and configured:
   ```bash
   aws configure
   aws sts get-caller-identity   # should return your account details
   ```
3. **Terraform** installed (v1.5.0 or later):
   ```bash
   terraform -version
   ```
4. **An existing EC2 Key Pair** in your target region (needed to SSH
   into the EC2 instance):
   ```bash
   aws ec2 create-key-pair --key-name my-ec2-keypair \
     --query 'KeyMaterial' --output text > my-ec2-keypair.pem
   chmod 400 my-ec2-keypair.pem
   ```
5. *(Optional, to interact with the cluster)* **kubectl** installed.

> ⚠️ **Cost warning:** NAT Gateway, EC2, and especially the EKS cluster
> (control plane has an hourly charge) are **not fully free-tier**.
> Running this project for a few hours to learn/demo it typically costs
> a small amount (a few dollars). **Always run `terraform destroy`**
> when you're done — see the Destroy section below.

---

## 🚀 Deployment Steps

### 1. Clone the repo
```bash
git clone https://github.com/<your-username>/aws-terraform-devops-fresher-project.git
cd aws-terraform-devops-fresher-project/terraform
```

### 2. Set up your variables
```bash
cp terraform.tfvars.example terraform.tfvars
```
Now open `terraform.tfvars` and update at least these values:
- `key_pair_name` → your existing EC2 key pair name
- `my_ip_cidr` → your public IP in CIDR format, e.g. `203.0.113.10/32`
  (check yours at https://whatismyip.com)
- `s3_bucket_name` → must be globally unique (add your name/date)

### 3. Initialize Terraform
```bash
terraform init
```
This downloads the AWS provider plugin and sets up the local backend.

### 4. Review the execution plan
```bash
terraform plan
```
This shows exactly what will be created — always review before applying.

### 5. Apply (create the infrastructure)
```bash
terraform apply
```
Type `yes` when prompted. This will take **roughly 15-20 minutes**,
mostly because EKS cluster creation is slow — that's normal, be patient.

### 6. Verify the outputs
Once complete, Terraform prints useful values like the EC2 public IP,
S3 bucket name, and EKS cluster endpoint.

To connect `kubectl` to your new cluster:
```bash
aws eks update-kubeconfig --region us-east-1 --name devops-fresher-eks-cluster
kubectl get nodes
```

To view the EC2 web page:
```
http://<ec2_public_ip>
```

---

## 🔥 Destroy Steps (IMPORTANT — avoid unexpected AWS charges)

When you're done exploring/demoing the project, tear everything down:

```bash
cd terraform
terraform destroy
```
Type `yes` when prompted. This removes every resource Terraform created
(EKS cluster + nodes, EC2, NAT Gateway, S3 bucket, VPC, IAM roles, etc.)

Then **double-check in the AWS Console** that these are gone (they're
the most expensive if left running by mistake):
- EC2 → Instances
- VPC → NAT Gateways
- EKS → Clusters
- EC2 → Elastic IPs (should have none allocated/unused)

> If `terraform destroy` fails partway through, see
> [`docs/troubleshooting.md`](docs/troubleshooting.md) — it's usually
> caused by a Kubernetes-created Load Balancer that Terraform doesn't
> know about.

---

## 🧩 What Each AWS Resource Does

- **VPC** — your own private, isolated network inside AWS, defined by
  an IP address range (CIDR block).
- **Public Subnet** — a section of the VPC that has a route to the
  internet via the Internet Gateway; used for resources that need to be
  reachable from outside (EC2, NAT Gateway).
- **Private Subnet** — a section of the VPC with no direct internet
  route; used for resources that should stay hidden (EKS worker nodes).
- **Internet Gateway (IGW)** — the "door" that lets the public subnet
  send/receive traffic to/from the internet.
- **NAT Gateway** — allows the private subnet to make *outbound*
  internet requests (e.g., pulling Docker images) without allowing
  *inbound* connections from the internet.
- **Route Tables** — the "rules" that decide which gateway each
  subnet's traffic goes through.
- **Security Group** — a virtual firewall around the EC2 instance,
  controlling allowed inbound/outbound ports (SSH, HTTP).
- **IAM Roles** — give AWS services and EC2 instances temporary,
  scoped permissions without hardcoding secret access keys.
- **EC2 Instance** — a virtual server; here it runs a simple Apache web
  page as a demo.
- **S3 Bucket** — durable, private, versioned object storage.
- **Amazon EKS Cluster** — a managed Kubernetes control plane, with a
  Managed Node Group of EC2 instances acting as worker nodes.

---

## 🎓 What I Learned

Building this project helped me understand, hands-on:

- How to structure a **Terraform project** using `providers.tf`,
  `variables.tf`, `main.tf`, and `outputs.tf` — instead of one giant
  file — while still keeping it simple (no complex module hierarchies).
- The **difference between public and private subnets**, and why
  production workloads (like Kubernetes nodes) are usually placed in
  private subnets.
- How **NAT Gateways vs Internet Gateways** serve very different
  purposes, and why both are usually needed together.
- Why **IAM Roles are safer than hardcoded AWS credentials**, and how
  instance profiles connect an IAM role to an EC2 instance.
- The basics of how **Amazon EKS** separates the managed control plane
  from the worker nodes I still need to manage.
- Why **Terraform state matters**, and why it (along with `.tfvars`
  files containing personal values) should never be committed to
  version control.
- The importance of **always running `terraform destroy`** after
  testing cloud infrastructure, to avoid unexpected billing.
- How to write **clean, well-commented Terraform code** that another
  engineer (or interviewer!) can read and understand without me
  explaining every line.

---

## 📚 More Docs

- [`docs/architecture.md`](docs/architecture.md) — ASCII architecture
  diagram and traffic flow explanation
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — common errors
  and how to fix them
- [`docs/interview-questions.md`](docs/interview-questions.md) — Q&A to
  help explain this project in interviews

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
