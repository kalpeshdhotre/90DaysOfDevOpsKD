# Day 65 — Terraform Modules: Build Reusable Infrastructure

## Task 1: Module Structure

A **root module** is the directory you run `terraform apply` from — it's the
entry point, the only place state and providers live. A **child module** is
anything called via `module "..." { source = ... }` — no state of its own,
resources get namespaced under `module.<name>.` in the root's state. Same idea
as a function: root module is `main()`, child modules are reusable functions
it calls.

![alt text](<md-screenshots/Screenshot From 2026-07-24 14-40-46.png>)

---

## Task 2: Custom EC2 Module

**`modules/ec2-instance/variables.tf`**

```hcl
variable "ami_id"             { type = string }
variable "instance_type"      { type = string; default = "t2.micro" }
variable "subnet_id"          { type = string }
variable "security_group_ids" { type = list(string) }
variable "instance_name"      { type = string }
variable "tags"               { type = map(string); default = {} }
```

**`modules/ec2-instance/main.tf`**

```hcl
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  tags = merge(var.tags, { Name = var.instance_name })
}
```

**`modules/ec2-instance/outputs.tf`**

```hcl
output "instance_id" { value = aws_instance.this.id }
output "public_ip"   { value = aws_instance.this.public_ip }
output "private_ip"  { value = aws_instance.this.private_ip }
```

---

## Task 3: Custom Security Group Module (with `dynamic` block)

**`modules/security-group/main.tf`**

```hcl
resource "aws_security_group" "this" {
  name   = var.sg_name
  vpc_id = var.vpc_id

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

  tags = var.tags
}
```

`for_each = var.ingress_ports` loops over the port list and stamps out one
`ingress {}` block per value — no more copy-pasting near-identical blocks by
hand for every port.

---

## Task 4: Wiring Custom Modules from Root

```hcl
module "web_sg" {
  source        = "./modules/security-group"
  vpc_id        = module.vpc.vpc_id
  sg_name       = "terraweek-web-sg"
  ingress_ports = [22, 80, 443]
  tags          = local.common_tags
}

module "web_server" {
  source             = "./modules/ec2-instance"
  ami_id             = data.aws_ami.amazon_linux.id
  instance_type      = "t2.micro"
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [module.web_sg.sg_id]
  instance_name      = "terraweek-web"
  tags               = local.common_tags
}

module "api_server" {
  source             = "./modules/ec2-instance"
  ami_id             = data.aws_ami.amazon_linux.id
  instance_type      = "t2.micro"
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [module.web_sg.sg_id]
  instance_name      = "terraweek-api"
  tags               = local.common_tags
}
```

Two EC2 instances, same module, different names — no code duplication.

![alt text](<md-screenshots/Screenshot From 2026-07-24 14-55-53.png>)
![alt text](<md-screenshots/Screenshot From 2026-07-24 14-56-26.png>)

---

## Task 5: Public Registry VPC Module

Replaced the hand-written `aws_vpc` / `aws_subnet` with:

```hcl
module "vpc" {
  source = "./modules/vpc-external"   # see Technical Callout below

  name = "terraweek-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = false
  enable_dns_hostnames = true

  tags = local.common_tags
}
```

**Comparison — hand-written VPC vs registry module:**

|                   | Hand-written (Day 62)       | Registry module (`terraform-aws-modules/vpc/aws` v6.6.1)                                          |
| ----------------- | --------------------------- | ------------------------------------------------------------------------------------------------- |
| Resources created | 2 (`aws_vpc`, `aws_subnet`) | 10+ (VPC, 4 subnets across 2 AZs, IGW, route tables, associations, DHCP options, default SG/NACL) |
| Lines of HCL      | ~15                         | ~12 (module call only)                                                                            |
| Multi-AZ handling | Manual                      | Built-in                                                                                          |

![alt text](<md-screenshots/Screenshot From 2026-07-24 16-10-23.png>)

---

## Task 6: Versioning, State, Cleanup

**Version pinning styles tried:**

```hcl
version = "6.6.1"           # exact
version = "~> 6.0"           # any 6.x
version = ">= 6.0, < 7.0"    # range
```

`terraform state list` confirmed module namespacing:

```
module.vpc.aws_vpc.this[0]
module.web_sg.aws_security_group.this
module.web_server.aws_instance.this
module.api_server.aws_instance.this
```

![alt text](<md-screenshots/Screenshot From 2026-07-24 16-10-23-1.png>)

`terraform destroy` run at the end — confirmed via AWS CLI/console that no
instances or NAT resources remained running.

**Five module best practices:**

1. Always pin versions for registry modules — an unpinned module can shift
   under you on the next `init`.
2. Keep modules focused — one concern per module.
3. Use variables for everything, hardcode nothing.
4. Always define outputs — callers can't reference what isn't exposed.
5. Document every custom module with a README.

---

## Technical Callout — Registry Module Download Bug

Hit a genuine Terraform CLI bug (v1.15.8) while pulling the official
`terraform-aws-modules/vpc/aws` module: both the registry-resolved commit SHA
_and_ a manually pinned git tag (`v6.6.1`, confirmed to exist via
`git ls-remote`) were rejected by Terraform's internal git downloader with
`invalid ref`, even though a plain `git clone` of the same tag worked fine
outside Terraform.

**Root cause: unconfirmed** — narrowed it down to Terraform's module-download
layer (not git, not network/proxy, not the tag itself), but the exact trigger
is still unresolved.

**Workaround that unblocked the lab:** git-cloned the module manually into
`modules/vpc-external/` and referenced it as a local path module (`source =
"./modules/vpc-external"`) instead of a git/registry source — this bypasses
Terraform's downloader entirely. Also had a secondary issue where the AWS
provider version was mistakenly pinned to `6.6.1` (the _module's_ version)
instead of a valid provider version — fixed to `>= 6.28.0`.

---

## Submission

- `day-65-modules.md` added to `2026/day-65/`
- Committed and pushed to fork
