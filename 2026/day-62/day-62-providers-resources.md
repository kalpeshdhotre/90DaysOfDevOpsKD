# Day 62 — Providers, Resources and Dependencies (Terraform + AWS)

Built a complete AWS networking stack with Terraform: VPC → subnet → internet gateway → route table → security group → EC2 instance → S3 bucket, all wired together through implicit and explicit dependencies.

---

## Task 1: Explore the AWS Provider

`providers.tf`:

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
```

```bash
terraform init
```

![alt text](<Screenshot From 2026-07-22 20-17-41.png>)

Read the lock file:

```bash
cat .terraform.lock.hcl
```

**`~> 5.0` vs `>= 5.0` vs `= 5.0.0`:**

- `~> 5.0` — pessimistic constraint. Allows any `5.x` version (e.g. `5.1`, `5.42`) but blocks `6.0`. This is what you want in most projects — you get bug fixes and minor features without an unexpected breaking major upgrade.
- `>= 5.0` — allows anything from `5.0` upward, including `6.0`, `7.0`, forever. Too loose for production; a major version bump could silently break your config.
- `= 5.0.0` — pinned to that exact version. Safest against drift, but you have to manually bump it for every fix or feature, even patches.

**What `.terraform.lock.hcl` does:** it records the exact provider version and checksums that were resolved and downloaded during `init`, so that every teammate (or CI pipeline) running `terraform init` afterward gets the _identical_ provider build — not just something matching `~> 5.0`. It should be committed to git for that reason, same idea as a `package-lock.json` or `Gemfile.lock`.

---

## Task 2: Build a VPC from Scratch

`main.tf` (networking section):

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "TerraWeek-VPC"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "TerraWeek-Public-Subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "TerraWeek-IGW"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "TerraWeek-Public-RT"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

```bash
terraform plan
```

![alt text](<Screenshot From 2026-07-23 04-16-27.png>)

```bash
terraform apply
```

![alt text](<Screenshot From 2026-07-23 04-19-41.png>)

![alt text](<Screenshot From 2026-07-23 04-24-12.png>)

![alt text](<Screenshot From 2026-07-23 04-25-19.png>)

All five resources created and connected correctly on the first apply.

---

## Task 3: Understand Implicit Dependencies

**How does Terraform know to create the VPC before the subnet?**
Because `aws_subnet.public` references `aws_vpc.main.id` in its `vpc_id` argument. Terraform parses every resource block, builds a dependency graph from these attribute references, and orders the apply so any resource being referenced is created first — no manual sequencing needed.

**What would happen if the subnet tried to create before the VPC existed?**
It would fail — the subnet's `vpc_id` would be empty or invalid since the VPC doesn't exist yet, so AWS would reject the `CreateSubnet` call. This is exactly why Terraform builds the dependency graph first: to guarantee this ordering never happens.

**All implicit dependencies found in the config:**

1. `aws_subnet.public` → depends on `aws_vpc.main.id`
2. `aws_internet_gateway.main` → depends on `aws_vpc.main.id`
3. `aws_route_table.public` → depends on `aws_vpc.main.id` **and** `aws_internet_gateway.main.id` (via the route block)
4. `aws_route_table_association.public` → depends on both `aws_route_table.public.id` and `aws_subnet.public.id`

So the actual apply order Terraform works out is: VPC → (subnet, IGW in parallel, since neither depends on the other) → route table → route table association.

---

## Task 4: Security Group and EC2 Instance

```hcl
resource "aws_security_group" "web" {
  name        = "terraweek-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TerraWeek-SG"
  }
}

resource "aws_instance" "main" {
  ami                          = "ami-XXXXXXXXXXXXXXXXX"
  instance_type                = "t3.micro"
  subnet_id                    = aws_subnet.public.id
  vpc_security_group_ids       = [aws_security_group.web.id]
  associate_public_ip_address  = true

  tags = {
    Name = "TerraWeek-Server"
  }
}
```

![alt text](<Screenshot From 2026-07-23 04-44-38.png>)

### 🐛 Real troubleshooting: instance type not supported in AZ

First apply failed:

```
Error: creating EC2 Instance: operation error EC2: RunInstances, ...
api error Unsupported: Your requested instance type (t2.micro) is not
supported in your requested Availability Zone (ap-south-1c). Please retry
your request by not specifying an Availability Zone or choosing
ap-south-1a, ap-south-1b.
```

AWS had placed the subnet in `ap-south-1c`, and `t2.micro` isn't offered in that particular AZ within `ap-south-1` (instance type availability varies per AZ, not just per region). Rather than fighting AZ placement, switched the instance type to `t3.micro` (also free-tier eligible, broader AZ support) — re-ran `terraform apply` and it succeeded. Good reminder that "free-tier eligible" doesn't mean "available everywhere" — worth checking `aws ec2 describe-instance-type-offerings` per AZ before pinning an instance type in a new region.

---

## Task 5: Explicit Dependency with `depends_on`

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "terraweek-logs-<unique-suffix>"

  tags = {
    Name = "TerraWeek-Logs"
  }

  depends_on = [aws_instance.main]
}
```

```bash
terraform plan
terraform apply
```

![alt text](<Screenshot From 2026-07-23 04-48-21.png>)

Dependency graph:

```bash
terraform graph | dot -Tpng > graph.png
```

![alt text](<Screenshot From 2026-07-23 04-51-40.png>)

### When would you use `depends_on` in real projects?

`depends_on` is for ordering that Terraform _can't_ infer from attribute references — usually when two resources are related operationally but not through any shared argument. Two examples:

1. **IAM role/policy propagation before use** — an EC2 instance or Lambda needs an IAM role, but AWS IAM permissions can take a few seconds to propagate after creation. Even though the instance references the role ARN (which _is_ an implicit dependency), sometimes you add `depends_on` on an `aws_iam_role_policy_attachment` to make sure the policy is fully attached before the compute resource that needs those permissions is created, since the attachment itself doesn't appear in any argument the instance reads.
2. **Application deployment order with no shared attributes** — e.g. an S3 bucket that receives logs from an EC2 instance (this exact task): there's no Terraform argument linking them, but you want the bucket to exist only after the instance (or vice versa, depending on your logging setup) for organizational/ordering reasons, not because any resource attribute requires it.

---

## Task 6: Lifecycle Rules and Destroy

```hcl
resource "aws_instance" "main" {
  ami                          = "ami-XXXXXXXXXXXXXXXXX"
  instance_type                = "t3.micro"
  subnet_id                    = aws_subnet.public.id
  vpc_security_group_ids       = [aws_security_group.web.id]
  associate_public_ip_address  = true

  tags = {
    Name = "TerraWeek-Server"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

Changed the AMI ID and ran `terraform plan`:
![alt text](<Screenshot From 2026-07-23 04-56-40.png>)

```bash
terraform destroy
```

![alt text](<Screenshot From 2026-07-23 05-00-10.png>)

Destroy order was the exact reverse of creation: S3 bucket → EC2 instance → security group → route table association → route table → internet gateway → subnet → VPC. Confirmed in AWS console — VPC, EC2 instance, and S3 bucket all cleaned up.

### The three lifecycle arguments

- **`create_before_destroy`** — provisions the replacement resource _before_ destroying the old one, instead of Terraform's default destroy-then-create. Use it for anything that can't have downtime, like this EC2 instance, a launch template behind an ASG, or a DNS record where you don't want a gap in resolution.
- **`prevent_destroy`** — blocks `terraform destroy` (and any plan that would destroy the resource) with a hard error unless the block is removed first. Use it on things that are catastrophic to lose by accident — production databases, S3 buckets holding critical data, KMS keys.
- **`ignore_changes`** — tells Terraform to stop tracking drift on specific attributes, so it won't try to "fix" changes made outside Terraform. Use it when something else manages part of a resource — e.g. an autoscaling group's `desired_capacity` that a scaling policy adjusts at runtime, or tags that get added by an external tagging compliance tool.

---

## Implicit vs Explicit Dependencies — in my own words

**Implicit dependencies** are the ones Terraform figures out on its own, just by reading your config. If Resource B has an argument that references an attribute of Resource A (like `vpc_id = aws_vpc.main.id`), Terraform knows A must exist first. This is the normal, preferred way — most of your dependency graph should come from these natural references, and you don't have to think about ordering at all, Terraform does it for you.

**Explicit dependencies** (`depends_on`) are for the rare case where two resources need to be sequenced but there's no argument connecting them — the relationship lives outside of Terraform's view (like IAM propagation timing, or "just create this after that one for operational reasons"). You should reach for `depends_on` sparingly; if you find yourself using it constantly, it's often a sign the resources should actually reference each other somehow.

---

## Key Takeaways

- Terraform builds its execution order from a dependency graph, not from the order resources appear in the file
- Implicit dependencies (attribute references) should cover 90%+ of real-world ordering needs
- `depends_on` exists for the cases Terraform genuinely can't infer — use it deliberately, not as a default
- Instance type availability is AZ-specific within a region, not just region-specific — always worth checking before pinning
- `terraform destroy` tears down in exact reverse dependency order, which is what keeps it safe
