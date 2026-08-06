# Day 67 — TerraWeek Capstone: Multi-Environment Infrastructure with Workspaces and Modules

## Overview

Seven days of Terraform came together in one project: a single codebase deploying three fully isolated environments (dev, staging, prod) using custom modules and Terraform workspaces — no copy-pasted directories, no manual console clicks.

---

## 1. Project Structure

```
terraweek-capstone/
  main.tf                   # Root module -- calls child modules
  variables.tf               # Root variables
  outputs.tf                 # Root outputs
  providers.tf                # AWS provider and backend
  locals.tf                   # Local values using workspace
  dev.tfvars                  # Dev environment values
  staging.tfvars              # Staging environment values
  prod.tfvars                 # Prod environment values
  .gitignore                  # Ignore state, .terraform, tfvars with secrets
  modules/
    vpc/
      main.tf
      variables.tf
      outputs.tf
    security-group/
      main.tf
      variables.tf
      outputs.tf
    ec2-instance/
      main.tf
      variables.tf
      outputs.tf
```

**Why this structure is best practice:**

- Single responsibility per root file — `providers.tf` only holds provider/backend config, `variables.tf` only declarations, `locals.tf` only derived values. Anyone opening the repo can find what they need immediately.
- `modules/` cleanly separates _reusable_ infrastructure (VPC, SG, EC2) from _environment wiring_ in root — each module is independently testable and reusable across projects.
- `.gitignore` keeps state files and `.terraform/` provider caches out of version control — state can contain sensitive data in plaintext and should never be committed.

![alt text](<md-screenshots/Screenshot From 2026-08-02 21-02-37.png>)

---

## 2. Terraform Workspaces

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
terraform workspace list
```

**Q: What does `terraform.workspace` return inside a config?**
The name of the currently selected workspace as a string (`"dev"`, `"staging"`, `"prod"`) — usable anywhere in HCL, e.g. for tagging or naming.

**Q: Where does each workspace store its state file?**
Locally: `terraform.tfstate.d/<workspace_name>/terraform.tfstate`. With a remote S3 backend: key becomes `env:/<workspace_name>/<original_key>`.

**Q: How is this different from separate directories per environment?**
Separate directories = fully independent codebases that can drift apart over time. Workspaces = one codebase, one set of `.tf` files, state isolated per workspace — DRY, but all environments share identical resource structure (differences come only from variables, not code).

## ![alt text](<md-screenshots/Screenshot From 2026-08-02 20-57-07.png>)

## 3. Custom Modules

### Module 1: `modules/vpc/`

Creates a VPC, public subnet, internet gateway, route table, and route table association.

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

**Outputs:** `vpc_id`, `subnet_id`

---

### Module 2: `modules/security-group/`

Dynamic ingress rules driven by a list of ports; open egress.

```hcl
# modules/security-group/main.tf
resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for ${var.project_name} ${var.environment}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      description = "Allow port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
```

**Output:** `sg_id`

---

### Module 3: `modules/ec2-instance/`

```hcl
# modules/ec2-instance/main.tf
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-server"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
```

**Outputs:** `instance_id`, `public_ip`

---

## 4. Root Module — Workspace-Aware Wiring

```hcl
# locals.tf
locals {
  environment = terraform.workspace
  name_prefix = "${var.project_name}-${local.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Workspace   = terraform.workspace
  }
}
```

```hcl
# main.tf
module "vpc" {
  source              = "./modules/vpc"
  cidr                = var.vpc_cidr
  public_subnet_cidr  = var.subnet_cidr
  environment         = local.environment
  project_name        = var.project_name
}

module "security_group" {
  source        = "./modules/security-group"
  vpc_id        = module.vpc.vpc_id
  ingress_ports = var.ingress_ports
  environment   = local.environment
  project_name  = var.project_name
}

module "ec2_instance" {
  source              = "./modules/ec2-instance"
  ami_id              = var.ami_id
  instance_type       = var.instance_type
  subnet_id           = module.vpc.subnet_id
  security_group_ids  = [module.security_group.sg_id]
  environment         = local.environment
  project_name        = var.project_name
}
```

`terraform.workspace` flows from `locals.tf` → every module call → every resource tag, so the exact same code produces three differently-named, differently-sized, differently-isolated environments purely based on which workspace is active.

---

## 5. Environment-Specific tfvars

| Variable        | dev           | staging         | prod          |
| --------------- | ------------- | --------------- | ------------- |
| `vpc_cidr`      | `10.0.0.0/16` | `10.1.0.0/16`   | `10.2.0.0/16` |
| `subnet_cidr`   | `10.0.1.0/24` | `10.1.1.0/24`   | `10.2.1.0/24` |
| `instance_type` | `t2.micro`    | `t2.small`      | `t3.small`    |
| `ingress_ports` | `[22, 80]`    | `[22, 80, 443]` | `[80, 443]`   |

**Key difference to note:** dev and staging allow SSH (port 22); **prod does not** — production traffic only accepts HTTP/HTTPS, forcing any prod access through proper channels (SSM Session Manager, bastion, etc.) instead of open SSH.

## ![alt text](<md-screenshots/Screenshot From 2026-08-03 20-44-11-1.png>)

## 6. Deployment Verification

```
[SCREENSHOT: AWS Console — all 3 VPCs listed together with distinct CIDR ranges]
[SCREENSHOT: AWS Console — all 3 EC2 instances listed together, showing t2.micro / t2.small / t3.small]
[SCREENSHOT: terraform output for dev workspace]
[SCREENSHOT: terraform output for staging workspace]
[SCREENSHOT: terraform output for prod workspace]
```

**Isolation confirmed:** each workspace maintains its own state file (`terraform.tfstate.d/<workspace>/terraform.tfstate`), so `dev`, `staging`, and `prod` resource addresses never collide — despite sharing identical `.tf` code. Distinct CIDR ranges additionally rule out any accidental VPC peering/routing overlap between environments.

---

## 7. Terraform Best Practices Guide

Everything learned across TerraWeek (Days 61–67), consolidated:

1. **File structure** — separate files for providers, variables, outputs, main, locals. Keeps large projects navigable and code-review-friendly.
2. **State management** — always use a remote backend (S3 + DynamoDB for locking), enable state locking to prevent concurrent-apply corruption, enable S3 versioning for state rollback.
3. **Variables** — never hardcode environment-specific values; use one `.tfvars` per environment; add `validation` blocks to catch bad input at plan time, not apply time.
4. **Modules** — one concern per module (VPC ≠ SG ≠ EC2); always define explicit inputs/outputs as the module's contract; pin registry module versions (`version = "~> 5.0"`) to avoid silent breaking changes.
5. **Workspaces** — use for environment isolation within one codebase; reference `terraform.workspace` for naming/tagging so resources self-identify their environment.
6. **Security** — `.gitignore` state and tfvars containing secrets; encrypt state at rest (S3 SSE); restrict backend bucket access via IAM.
7. **Commands** — always `terraform plan` before `apply`, never skip the diff review; run `fmt` and `validate` before every commit to keep HCL clean and catch syntax errors early.
8. **Tagging** — tag every resource with Project, Environment, and ManagedBy so cost allocation and cleanup are always traceable.
9. **Naming** — consistent `<project>-<environment>-<resource>` pattern makes resources instantly identifiable in the AWS console.
10. **Cleanup** — always `terraform destroy` non-production environments when not actively in use; idle dev/staging infra is pure cost with zero benefit.

---

## 8. TerraWeek Day-by-Day Recap

| Day | Concepts                                            |
| --- | --------------------------------------------------- |
| 61  | IaC, HCL, init/plan/apply/destroy, state basics     |
| 62  | Providers, resources, dependencies, lifecycle       |
| 63  | Variables, outputs, data sources, locals, functions |
| 64  | Remote backend, locking, import, drift              |
| 65  | Custom modules, registry modules, versioning        |
| 66  | EKS with modules, real-world provisioning           |
| 67  | Workspaces, multi-env, capstone project             |

---

## 9. Cleanup

```bash
terraform workspace select prod    && terraform destroy -var-file="prod.tfvars"    -auto-approve
terraform workspace select staging && terraform destroy -var-file="staging.tfvars" -auto-approve
terraform workspace select dev     && terraform destroy -var-file="dev.tfvars"     -auto-approve

terraform workspace select default
terraform workspace delete dev
terraform workspace delete staging
terraform workspace delete prod
```

```
[SCREENSHOT: terraform workspace list showing only "default"]
[SCREENSHOT: AWS Console — clean state, no terraweek-* resources remaining]
```

All three environments destroyed cleanly. Account verified clean.

---

_#90DaysOfDevOps #TerraWeek #DevOpsKaJosh #TrainWithShubham_
