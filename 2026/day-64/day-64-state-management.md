# Day 64 — Terraform State Management and Remote Backends

State is the single source of truth between your `.tf` files and what actually exists in the cloud. Today's focus: moving state from local to a remote S3 backend with DynamoDB locking, importing existing infra, doing state surgery, and simulating/fixing drift.

---

## Diagram: Local State vs Remote State

```
LOCAL STATE                          REMOTE STATE (S3 + DynamoDB)
──────────────                       ─────────────────────────────
terraform apply                      terraform apply
     │                                    │
     ▼                                    ▼
terraform.tfstate                   S3: dev/terraform.tfstate
(on your machine only)              (versioned, encrypted)
     │                                    │
- single point of failure           - shared across team/CI
- no locking → race conditions      - DynamoDB LockID → locking
- lost laptop = lost state          - S3 versioning = recoverable
```

---

## Task 1: Inspect Current State

```bash
terraform show
terraform state list
terraform state show aws_instance.web
terraform state show aws_vpc.main
```

![alt text](<Screenshot From 2026-07-24 05-41-16.png>)
![alt text](<Screenshot From 2026-07-24 05-42-08.png>)

**Q1: How many resources does Terraform track?**
3 — `aws_vpc.main`, `aws_subnet.public`, `aws_instance.web`.

**Q2: What attributes does state store beyond what's defined?**
Way more than the `.tf` file declares — `arn`, `id`, `private_ip`, `public_ip`, `availability_zone`, `network_interface_id`, `root_block_device`, `primary_network_interface_id`, and dozens of provider-computed defaults. The `.tf` file is the intent; the state file is the full observed reality.

**Q3: What does `serial` represent?**
A counter Terraform increments every time it writes the state file. It's how Terraform and remote backends detect that state has moved forward and decide which copy is authoritative — the backbone of conflict/staleness detection.

---

## Task 2: S3 Remote Backend

```bash
aws s3api create-bucket \
  --bucket terraweek-state-kalpeshdhotre \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket terraweek-state-kalpeshdhotre \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraweek-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

```hcl
terraform {
  backend "s3" {
    bucket         = "terraweek-state-kalpeshdhotre"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraweek-state-lock"
    encrypt        = true
  }
}
```

```bash
terraform init    # prompted to migrate existing state → yes
terraform plan    # No changes — migration confirmed clean
```

![alt text](<Screenshot From 2026-07-24 05-56-46.png>)

**Real issue hit:** every command against this backend threw a deprecation warning:

```
Warning: Deprecated Parameter
The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```

Terraform 1.10+ added S3-native locking via `use_lockfile = true`, which uses S3 conditional writes instead of a separate DynamoDB table, and the classic `dynamodb_table` argument is now flagged as deprecated (though still functional). Kept `dynamodb_table` for this challenge since the task specifically targets DynamoDB locking, but noted `use_lockfile` as the modern replacement for future configs.

---

## Task 3: State Locking

Ran `terraform apply` in Terminal 1 and paused at the confirmation prompt (first attempt had `No changes` with nothing to confirm — fixed by adding a new tag to force a real diff). While it waited, ran `terraform plan` in Terminal 2:

```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        <uuid>
  Path:      terraweek-state-kalpeshdhotre/dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       kd@hostname
```

![alt text](<Screenshot From 2026-07-24 06-06-30.png>)

**Why locking matters for teams:** without it, two people running `apply` at the same time can both read the same state and write conflicting changes — the second write silently clobbers the first. That corrupts the state file and can leave Terraform blind to real infrastructure (leaked resources, duplicate creates, accidental deletes). The DynamoDB table's `LockID` key is what turns this from "hope nobody applies at the same time" into an enforced guarantee.

---

## Task 4: Import an Existing Resource

```bash
aws s3api create-bucket \
  --bucket terraweek-import-test-kalpeshdhotre \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

```hcl
resource "aws_s3_bucket" "imported" {
  bucket = "terraweek-import-test-kalpeshdhotre"
}
```

```bash
terraform import aws_s3_bucket.imported terraweek-import-test-kalpeshdhotre
terraform plan   # reconciled to "No changes"
terraform state list
```

![alt text](<Screenshot From 2026-07-24 08-18-12.png>)
![alt text](<Screenshot From 2026-07-24 08-19-04.png>)

**`terraform import` vs creating from scratch:** import only links an _existing_ AWS resource into Terraform's state — it doesn't touch AWS and doesn't generate config for you. You're responsible for hand-writing a `.tf` block that matches what's already there; any mismatch shows up as a diff on the next plan. Creating from scratch, Terraform provisions and tracks the resource in one step, so config and reality start in sync by construction.

---

## Task 5: State Surgery — `mv` and `rm`

```bash
terraform state mv aws_s3_bucket.imported aws_s3_bucket.logs_bucket
# updated .tf block name to match
terraform plan   # No changes — bucket untouched in AWS

terraform state rm aws_s3_bucket.logs_bucket
terraform plan   # Terraform now wants to "create" it — bucket still alive in AWS

terraform import aws_s3_bucket.logs_bucket terraweek-import-test-kalpeshdhotre
```

![alt text](<Screenshot From 2026-07-24 08-22-03.png>)
![alt text](<Screenshot From 2026-07-24 08-24-09.png>)

**When to use each:**

- `state mv` — renaming a resource, or refactoring into a module/splitting configs, without destroying and recreating the real resource.
- `state rm` — handing a resource off to another team's Terraform config, or excluding something you want to manage manually, while leaving the real infrastructure completely untouched.

---

## Task 6: Simulate and Fix State Drift

Applied full config to sync, then manually added a `Name` tag on the EC2 instance in the AWS console — changed it to `ManuallyChanged`.

![alt text](<Screenshot From 2026-07-24 08-35-11.png>)

```bash
terraform plan
```

Diff showed the `Name` tag mismatch between AWS reality and the `.tf` config.

![alt text](<Screenshot From 2026-07-24 08-36-29.png>)

Chose **Option A** — reconciled by running `terraform apply` to force AWS back to match config.

![alt text](<Screenshot From 2026-07-24 08-37-01.png>)

```bash
terraform plan   # No changes — drift resolved
```

**How teams prevent drift in production:**

- Restrict console/CLI write access; all changes go through Terraform only
- Route infra changes through CI/CD (plan on PR, apply on merge) instead of local applies
- Scheduled `terraform plan` in CI to continuously detect drift
- IAM policies / SCPs blocking manual changes to Terraform-managed resource types
- Tag resources `ManagedBy = Terraform` and alert on untagged manual edits

---

## Cleanup — Real Troubleshooting

Ran `terraform destroy` to tear down and hit two separate real issues:

**Issue 1 — Lock acquisition failure:**

```
Error: Error acquiring the state lock
ResourceNotFoundException: Requested resource not found
Unable to retrieve item from DynamoDB table "terraweek-state-lock"
```

The DynamoDB lock table had already been deleted earlier in cleanup, so Terraform couldn't acquire a lock at all. Fixed with `terraform destroy -lock=false` — safe here since I was the only one touching this state.

**Issue 2 — Destroy reported nothing to destroy, but AWS resources still existed:**

```
No changes. No objects need to be destroyed.
Destroy complete! Resources: 0 destroyed.
```

`terraform state list` came back empty — the VPC, subnet, and EC2 instance from Task 1 were still running in AWS, but Terraform had no record of them (residue from the `state rm` practice in Task 5 plus a backend re-init). Terraform can only destroy what it knows about — an empty state means it has nothing to act on, even if real infra is sitting there.

**Resolution:** deleted the orphaned resources directly via AWS CLI instead of through Terraform:

```bash
aws ec2 terminate-instances --region ap-south-1 --instance-ids <instance-id>
aws ec2 delete-subnet --region ap-south-1 --subnet-id <subnet-id>
aws ec2 delete-vpc --region ap-south-1 --vpc-id <vpc-id>

aws s3 rm s3://terraweek-import-test-kalpeshdhotre --recursive
aws s3api delete-bucket --bucket terraweek-import-test-kalpeshdhotre --region ap-south-1

aws s3 rm s3://terraweek-state-kalpeshdhotre --recursive
aws s3api delete-bucket --bucket terraweek-state-kalpeshdhotre --region ap-south-1
```

**Key lesson:** Terraform's authority is only as good as its state. Once state and reality diverge — whether through `state rm`, a botched migration, or a deleted lock table — Terraform stops being the source of truth, and you have to fall back to the cloud provider's own tools to clean up. This is exactly why remote state with versioning and locking matters: it minimizes the chances of state and reality silently drifting apart.

---

## Summary: When to Use What

| Command                                     | Use case                                                             |
| ------------------------------------------- | -------------------------------------------------------------------- |
| `terraform import`                          | Bring an existing, unmanaged resource under Terraform                |
| `terraform state mv`                        | Rename a resource / refactor into a module without recreating it     |
| `terraform state rm`                        | Stop tracking a resource without destroying it                       |
| `terraform force-unlock`                    | Clear a stale lock — only when certain no other operation is running |
| `terraform refresh` / `apply -refresh-only` | Sync state to match real infra without changing anything             |
| `terraform destroy -lock=false`             | Bypass a broken/missing lock backend (solo use only)                 |
