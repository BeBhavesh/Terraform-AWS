# Interview Questions & Answers

These are common questions an interviewer might ask about this project.
Answers are written the way a fresher should explain them — simple,
confident, and accurate (no over-claiming).

---

### Q1. What does this project do, in one line?

**A:** It uses Terraform to provision a small AWS network (VPC, subnets,
NAT/Internet gateways) along with an EC2 web server, an S3 bucket, and a
Kubernetes cluster on Amazon EKS.

---

### Q2. Why did you use Terraform instead of manually creating resources
in the AWS Console?

**A:** Terraform lets me define infrastructure as code. That means it's
version-controlled, repeatable, and reviewable — I can create the exact
same environment again by running `terraform apply`, and destroy it
completely with `terraform destroy`, instead of manually clicking
through the console and risking mistakes or forgetting to delete things
(which costs money).

---

### Q3. What is the difference between a public subnet and a private
subnet?

**A:** A public subnet has a route to the Internet Gateway, so resources
in it (like my EC2 instance) can have public IPs and be reached directly
from the internet. A private subnet has no direct route to the internet
— its only way out is through a NAT Gateway, so resources there (like my
EKS worker nodes) can make outbound requests (e.g., pull container
images) but can't be reached directly from outside.

---

### Q4. Why do you need a NAT Gateway if you already have an Internet
Gateway?

**A:** The Internet Gateway allows two-way traffic and is used by the
public subnet. The NAT Gateway allows only one-way (outbound) traffic
for private subnet resources — they can reach the internet, but nothing
from the internet can initiate a connection to them. This keeps the EKS
worker nodes more secure since they aren't directly exposed.

---

### Q5. What's the purpose of Route Tables?

**A:** Route tables decide where network traffic goes. My public route
table sends all outbound traffic (`0.0.0.0/0`) to the Internet Gateway.
My private route table sends all outbound traffic to the NAT Gateway
instead. Each subnet is associated with one route table.

---

### Q6. What is a Security Group?

**A:** It's a virtual firewall attached to resources like EC2 instances.
It controls which traffic is allowed in (ingress) and out (egress). In
my project, the EC2 security group only allows SSH (port 22) from my own
IP address and HTTP (port 80) from anywhere.

---

### Q7. Why did you use an IAM Role for EC2 instead of hardcoding AWS
access keys?

**A:** Hardcoding access keys is a security risk — if the code or
instance is ever exposed, the keys can be stolen and misused. An IAM
Role, attached via an Instance Profile, lets the EC2 instance
automatically get temporary, rotated credentials to call AWS services
like S3, without ever storing a secret key anywhere.

---

### Q8. What is the difference between an IAM Role and an IAM User?

**A:** An IAM User represents a person or application with long-term
credentials (access key + secret key). An IAM Role has no long-term
credentials — it's "assumed" temporarily by a trusted entity (like an
EC2 instance or the EKS service) and provides short-lived, automatically
rotated credentials. Roles are safer for services.

---

### Q9. What does Amazon EKS actually manage for you, versus what do you
manage?

**A:** AWS manages the Kubernetes control plane (API server, etcd,
scheduler) — I don't need to install or patch those myself. I manage the
worker nodes (via a Managed Node Group, which still lets AWS handle
patching of the node OS), and I manage what gets deployed onto the
cluster (my applications/workloads).

---

### Q10. Why did you put EKS worker nodes in the private subnet?

**A:** For security — the worker nodes don't need to be directly
reachable from the internet. They only need outbound access (to pull
container images, call the EKS API, etc.), which the NAT Gateway
provides. This reduces the attack surface compared to putting them in a
public subnet.

---

### Q11. What is Terraform state, and why does it matter?

**A:** Terraform state (`terraform.tfstate`) is a file that records what
resources Terraform has created and their current configuration. It's
how Terraform knows what to change, create, or destroy on the next
`plan`/`apply`. It should never be manually edited, and it should never
be committed to a public repo since it can contain sensitive data — I've
added it to `.gitignore`.

---

### Q12. What's the difference between `terraform plan` and `terraform
apply`?

**A:** `terraform plan` shows a preview of what changes Terraform
*would* make, without changing anything. `terraform apply` actually
executes those changes and creates/updates/destroys real AWS resources.
I always run `plan` first to review before applying.

---

### Q13. Why is `terraform.tfvars` in `.gitignore` but
`terraform.tfvars.example` is not?

**A:** `terraform.tfvars` contains my personal/actual values (which
might include things I don't want public, like my real IP address or
specific bucket names). `terraform.tfvars.example` is a template with
placeholder values so anyone cloning the repo knows what variables they
need to set, without exposing my real configuration.

---

### Q14. What would you improve if this were a real production project?

**A:** I'd add: remote state storage (S3 + DynamoDB locking) instead of
local state, multiple Availability Zones for high availability, separate
environments (dev/staging/prod) using workspaces or separate state
files, stricter security group rules, private-only EKS API endpoint,
and CI/CD to run `terraform plan`/`apply` automatically. I kept this
project intentionally simple since it's a learning/portfolio project,
not a production system.

---

### Q15. How do you make sure you don't get charged unexpectedly after
testing this?

**A:** I always run `terraform destroy` when I'm done testing, and I
double check in the AWS Console that the NAT Gateway, EKS cluster, and
EC2 instance are actually gone — those are the most expensive resources
in this project if left running.
