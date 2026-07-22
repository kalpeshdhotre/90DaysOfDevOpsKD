# Day 61 — Introduction to Terraform and My First AWS Infrastructure

## Overview

Today marked the start of the Infrastructure as Code journey. After weeks of deploying containers and orchestrating workloads on Kubernetes, it was time to go one layer down — creating the actual cloud infrastructure (S3 + EC2) using nothing but a `.tf` file and Terraform's CLI lifecycle: `init → plan → apply → destroy`.

---

## Task 1: Infrastructure as Code — Notes

**What is IaC, and why does it matter in DevOps?**
IaC means defining servers, storage, and networking in code instead of clicking through a cloud console. It matters because it makes infrastructure repeatable, version-controlled, and reviewable — the same way application code is.

**What problems does IaC solve vs. the AWS console?**
Manual console changes aren't tracked anywhere — there's no history, no diff, no easy way to reproduce an environment for staging vs. production. IaC turns infrastructure changes into pull requests: reviewable, auditable, and repeatable across environments without relying on memory or screenshots of "what I clicked last time."

**Terraform vs. CloudFormation, Ansible, and Pulumi:**
CloudFormation is AWS-only and declarative — great if you're 100% AWS, but it doesn't travel. Ansible is primarily a configuration management tool (installing packages, managing config on existing servers) and is procedural/imperative by default, whereas Terraform focuses on _provisioning_ the infrastructure itself. Pulumi is declarative like Terraform but lets you write in general-purpose languages (Python, TypeScript, Go) instead of HCL — a tradeoff between familiarity and Terraform's purpose-built, more constrained syntax.

**Declarative and cloud-agnostic:**
"Declarative" means you describe the end state you want (a bucket, an instance with certain tags) and Terraform figures out the steps to get there — you don't script the individual API calls. "Cloud-agnostic" means the same core workflow (`init/plan/apply/destroy`) works across AWS, GCP, Azure, and dozens of other providers, just by swapping the provider block.

---

## Task 2: Install Terraform and Configure AWS

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y
terraform -version
```

AWS CLI configured with an IAM user's programmatic access keys, region set to `ap-south-1`:

```bash
aws configure
aws sts get-caller-identity
```

![alt text](<Screenshot From 2026-07-22 11-31-45.png>)

---

## Task 3: First Terraform Config — S3 Bucket

`main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "terraweek_bucket" {
  bucket = "terraweek-kalpeshdhotre-2026"

  tags = {
    Name = "TerraWeek-Day1"
  }
}
```

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

![alt text](<Screenshot From 2026-07-22 11-46-43.png>)
![alt text](<Screenshot From 2026-07-22 11-47-09.png>)
![alt text](<Screenshot From 2026-07-22 11-47-16.png>)
![alt text](<Screenshot From 2026-07-22 11-48-17.png>)

**What did `terraform init` download, and what's in `.terraform/`?**
`init` downloads the AWS provider plugin — the compiled `terraform-provider-aws` binary — into `.terraform/providers/`, matched to my OS/architecture. It also writes `.terraform.lock.hcl`, which pins the exact provider version so `apply` is reproducible across machines.

---

## Task 4: Add an EC2 Instance

Rather than hardcoding a region-specific AMI, I queried the current Amazon Linux 2 AMI for `ap-south-1` directly:

```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name]' \
  --output text \
  --region ap-south-1
```

Added to `main.tf`:

```hcl
resource "aws_instance" "terraweek_instance" {
  ami           = "ami-XXXXXXXXXXXXXXXXX"
  instance_type = "t2.micro"

  tags = {
    Name = "TerraWeek-Day1"
  }
}
```

```bash
terraform plan
terraform apply
```

![alt text](<Screenshot From 2026-07-22 11-52-40.png>)
![alt text](<Screenshot From 2026-07-22 11-53-08.png>)

**How does Terraform know the bucket already exists and only the EC2 instance needs creating?**
Terraform compares the `.tf` config against `terraform.tfstate`, resource by resource. The bucket already appears in state with a matching config, so `plan` shows zero changes for it — only the new `aws_instance` resource block, which has no matching state entry, shows up as "to add."

---

## Task 5: Inspecting the State File

```bash
terraform show
terraform state list
terraform state show aws_s3_bucket.terraweek_bucket
terraform state show aws_instance.terraweek_instance
```

![alt text](<Screenshot From 2026-07-22 11-56-51.png>)

**What does the state file store per resource?**
Every attribute AWS returned at creation time — not just what I wrote in `main.tf`. That includes ARNs, resource IDs, IP addresses, availability zone, and default values AWS assigned that were never explicitly set.

**Why never hand-edit the state file?**
Terraform diffs `main.tf` against state to decide what to create, change, or destroy. A manual edit that doesn't match real infrastructure causes drift — Terraform might then try to recreate a resource that already exists, or destroy something it thinks is orphaned.

**Why never commit it to Git?**
It can contain sensitive data in plaintext (IPs, resource IDs, sometimes secrets), and concurrent local edits from more than one person corrupt it. This is exactly the problem remote state backends (S3 + DynamoDB locking) solve — a topic for later in the week.

---

## Task 6: Modify, Plan, and Destroy

Changed the EC2 tag from `TerraWeek-Day1` to `TerraWeek-Modified`, then:

```bash
terraform plan
```

![alt text](<Screenshot From 2026-07-22 11-58-05.png>)

- `~` = in-place update — this change, since tags don't force replacement
- `+` = resource to be created
- `-` = resource to be destroyed
- `-/+` = destroy and recreate — would trigger if an immutable attribute like `ami` changed instead

```bash
terraform apply
```

![alt text](<Screenshot From 2026-07-22 11-59-09.png>)

Then tore it all down:

```bash
terraform destroy
```

![alt text](<Screenshot From 2026-07-22 12-00-42.png>)
![alt text](<Screenshot From 2026-07-22 12-01-39.png>)
![alt text](<Screenshot From 2026-07-22 12-00-58.png>)

---

## Terraform Commands — Quick Reference

| Command                | What it does                                                 |
| ---------------------- | ------------------------------------------------------------ |
| `terraform init`       | Downloads provider plugins, sets up the working directory    |
| `terraform plan`       | Shows what will change, without touching real infrastructure |
| `terraform apply`      | Executes the plan, creates/updates real resources            |
| `terraform destroy`    | Tears down every resource Terraform manages in this state    |
| `terraform show`       | Human-readable dump of the current state                     |
| `terraform state list` | Lists every resource Terraform is tracking                   |

---

## Why the State File Matters

It's the single source of truth Terraform diffs against on every `plan`. Without it, Terraform would have no way of knowing whether a resource in `main.tf` already exists in AWS or needs to be created — every `apply` would either fail on duplicates or recreate everything from scratch.

---

## Key Takeaway

IaC finally clicked today — not as a concept, but as a felt difference: watching `terraform destroy` cleanly remove exactly what `apply` created, with nothing left behind in the console, made the declarative model concrete in a way reading about it never did.
