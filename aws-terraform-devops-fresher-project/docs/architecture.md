# Architecture Diagram

This project provisions a simple, single-AZ AWS network with an EC2 server,
an S3 bucket, and a small EKS (Kubernetes) cluster.

```
                                   AWS CLOUD
   ┌───────────────────────────────────────────────────────────────────────┐
   │                                                                       │
   │                        VPC (10.0.0.0/16)                             │
   │                                                                       │
   │   ┌───────────────────────────┐     ┌───────────────────────────┐    │
   │   │   PUBLIC SUBNET            │     │   PRIVATE SUBNET           │    │
   │   │   (10.0.1.0/24)            │     │   (10.0.2.0/24)            │    │
   │   │                            │     │                            │    │
   │   │   ┌────────────────────┐   │     │   ┌────────────────────┐   │    │
   │   │   │   EC2 Instance     │   │     │   │  EKS Worker Node(s) │   │    │
   │   │   │  (Web Server)      │   │     │   │  (Managed Node      │   │    │
   │   │   │  + Security Group  │   │     │   │   Group)            │   │    │
   │   │   │  + IAM Role        │   │     │   └──────────┬──────────┘   │    │
   │   │   └─────────┬──────────┘   │     │              │              │    │
   │   │             │              │     │              │              │    │
   │   │   ┌─────────┴──────────┐   │     │              │              │    │
   │   │   │   NAT Gateway      │◄──┼─────┼──────────────┘              │    │
   │   │   │   (+ Elastic IP)   │   │     │   (private → internet       │    │
   │   │   └─────────┬──────────┘   │     │    via NAT, one-way only)   │    │
   │   │             │              │     └───────────────────────────┘    │
   │   └─────────────┼──────────────┘                                      │
   │                 │                                                     │
   │        ┌────────┴─────────┐                                           │
   │        │ Internet Gateway │                                           │
   │        └────────┬─────────┘                                           │
   │                 │                                                     │
   │      ┌──────────┴───────────┐                                         │
   │      │  Route Tables:       │                                         │
   │      │  - Public  → IGW     │                                         │
   │      │  - Private → NAT GW  │                                         │
   │      └──────────────────────┘                                         │
   │                                                                       │
   │        ┌───────────────────────────────────────────┐                 │
   │        │        EKS Cluster (Control Plane)         │                 │
   │        │   spans Public + Private Subnets            │                 │
   │        │   IAM Role: eks-cluster-role                │                 │
   │        └───────────────────────────────────────────┘                 │
   │                                                                       │
   └───────────────────────────────────────────────────────────────────────┘
                 │
                 │  (independent, regional service - not inside VPC)
                 ▼
      ┌─────────────────────┐
      │      S3 Bucket        │
      │  (private, versioned) │
      └─────────────────────┘

                     ▲
                     │  internet users
              ┌──────┴───────┐
              │  Your Laptop  │
              │ (SSH / kubectl│
              │  / browser)   │
              └───────────────┘
```

## Flow explanation

1. **Your laptop** connects to the internet, which reaches the **Internet
   Gateway (IGW)** attached to the VPC.
2. The **public subnet** is directly reachable from the internet via the IGW.
   The **EC2 instance** here has a public IP and runs a simple web server.
3. The **private subnet** has NO direct route to the internet. Its only path
   out is through the **NAT Gateway**, which lives in the public subnet.
   This is where the **EKS worker nodes** live — they can pull container
   images from the internet, but nothing from the internet can reach them
   directly.
4. **Route tables** decide traffic direction:
   - Public route table → sends `0.0.0.0/0` traffic to the IGW.
   - Private route table → sends `0.0.0.0/0` traffic to the NAT Gateway.
5. The **EKS Cluster control plane** is managed by AWS and spans both
   subnets so it can talk to resources in either one.
6. The **S3 bucket** is a separate, regional service — it's not "inside"
   the VPC, but the EC2 instance can reach it using its **IAM role**
   (no access keys needed).
7. **Security Groups** act like a firewall around the EC2 instance,
   only allowing SSH (port 22, from your IP) and HTTP (port 80).
