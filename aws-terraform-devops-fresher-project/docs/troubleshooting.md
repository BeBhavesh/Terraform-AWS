# Common Troubleshooting

A list of issues fresher engineers commonly hit while running this project,
and how to fix them.

---

### 1. `Error: error configuring Terraform AWS Provider: no valid credential sources found`

**Cause:** AWS CLI is not configured, or credentials are missing/expired.

**Fix:**
```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region, and output format
```
Verify with:
```bash
aws sts get-caller-identity
```

---

### 2. `Error: creating S3 Bucket: BucketAlreadyExists`

**Cause:** S3 bucket names must be **globally unique** across ALL AWS
accounts worldwide, not just your account.

**Fix:** Change `s3_bucket_name` in `terraform.tfvars` to something more
unique, e.g. add your name/date:
```
s3_bucket_name = "devops-fresher-bucket-yourname-2026"
```

---

### 3. `Error: InvalidKeyPair.NotFound`

**Cause:** The `key_pair_name` variable points to an EC2 key pair that
doesn't exist in your AWS account/region.

**Fix:** Create a key pair first:
```bash
aws ec2 create-key-pair --key-name my-ec2-keypair \
  --query 'KeyMaterial' --output text > my-ec2-keypair.pem
chmod 400 my-ec2-keypair.pem
```
Then set `key_pair_name = "my-ec2-keypair"` in `terraform.tfvars`.

---

### 4. `Error: UnauthorizedOperation` or `AccessDenied`

**Cause:** Your IAM user/role doesn't have enough permissions to create
VPC, EC2, EKS, IAM, or S3 resources.

**Fix:** For learning purposes, attach `AdministratorAccess` to your IAM
user (only in a personal/sandbox AWS account, never in production/shared
accounts). In real jobs, ask your AWS admin for the correct permissions.

---

### 5. `terraform apply` takes 15-20 minutes and seems "stuck"

**Cause:** This is normal! **EKS cluster creation genuinely takes
10-15 minutes**, and the node group takes a few more minutes after that.
NAT Gateway creation can also take 1-2 minutes.

**Fix:** Just wait. Don't cancel the apply — cancelling mid-creation can
leave resources in a broken/half-created state that's hard to clean up.

---

### 6. Can't SSH into the EC2 instance

**Checklist:**
- Is your `my_ip_cidr` variable set to YOUR current public IP? (IPs
  change, especially on home Wi-Fi — recheck at https://whatismyip.com)
- Are you using the correct `.pem` key file and correct username
  (`ec2-user` for Amazon Linux)?
  ```bash
  ssh -i my-ec2-keypair.pem ec2-user@<ec2_public_ip>
  ```
- Did the Security Group actually attach? Check in AWS Console →
  EC2 → Instances → Security tab.

---

### 7. `kubectl` can't connect to the EKS cluster

**Cause:** Your local kubeconfig isn't pointing at the new cluster.

**Fix:** Run the command shown in Terraform's `configure_kubectl` output:
```bash
aws eks update-kubeconfig --region us-east-1 --name devops-fresher-eks-cluster
kubectl get nodes
```
If nodes don't show up, wait a few minutes — node registration takes
time after the node group is created.

---

### 8. `terraform destroy` fails or hangs on VPC/Subnet deletion

**Cause:** Some resource (often a Load Balancer created by EKS, or an
ENI attached to the NAT Gateway) is still using the VPC/Subnet and
wasn't created by Terraform, so Terraform can't delete it automatically.

**Fix:**
1. Check the AWS Console → EC2 → Load Balancers, and delete any that
   were created by Kubernetes Services of type `LoadBalancer`.
2. Re-run `terraform destroy`.
3. As a last resort, manually delete the leftover resource in the
   Console, then run `terraform destroy` again.

---

### 9. `Error: expected length of ... to be in the range (3 - 63)` (S3 bucket name)

**Cause:** S3 bucket names must be 3-63 characters, lowercase letters,
numbers, and hyphens only (no underscores, no uppercase).

**Fix:** Update `s3_bucket_name` to follow these rules.

---

### 10. Terraform plan shows changes every time even with no edits

**Cause:** Usually happens with EKS/tags due to AWS auto-adding tags,
or provider version drift.

**Fix:** Pin provider version (already done in `providers.tf` via
`~> 5.0`), and run `terraform plan` again — small "no-op" diffs on tags
are common and not something to worry about as a fresher.
