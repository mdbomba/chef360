# Chef 360 on AWS — Terraform

Terraform module that provisions AWS infrastructure and automatically installs single-node **Chef 360 Platform** on EC2.

---

## Features

- Provisions VPC, subnets, internet gateway, and route tables
- Creates security groups aligned with Chef 360 port requirements
- Launches EC2 instances sized for the selected topology
- Automatically downloads, extracts, and installs the Chef 360 binary via SSH
- Optional Route 53 DNS records
- Optional Amazon RDS for PostgreSQL
- Optional Amazon S3 for Courier job data and centralized logs

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Terraform ≥ 1.5 | [Install guide](https://developer.hashicorp.com/terraform/install) |
| AWS credentials configured | `aws configure` or environment variables |
| An existing EC2 key pair | Used for SSH access to nodes |
| Ubuntu AMI (22.04 recommended) | Chef 360 requires Ubuntu |
| Chef 360 download authorization token | From the Progress Chef portal |

---

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd <repo-dir>

# 2. Copy and edit the example vars file
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars with your values (see Configuration below)

# 4. Initialize Terraform
terraform init

# 5. Preview changes
terraform plan

# 6. Apply — Terraform will prompt for your Admin Console password
terraform apply
```

---

## Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` and set at minimum:

```hcl
aws_region   = "us-east-1"
topology     = "single_node"          # See topologies below
key_name     = "my-ec2-key"           # Existing AWS key pair name
node_ami_id  = "ami-xxxxxxxxxxxxxxxxx" # Ubuntu 22.04 AMI for your region
ssh_private_key_path = "~/.ssh/my-ec2-key.pem"

# Restrict SSH and Admin Console access to your IP only
ssh_cidr_blocks   = ["YOUR_PUBLIC_IP/32"]
admin_cidr_blocks = ["YOUR_PUBLIC_IP/32"]

common_tags = {
  Owner = "your-name"
}
```

> **Admin Console password** is not stored in `terraform.tfvars`. Terraform will prompt you to enter it securely at `apply` time. To skip the prompt on repeated runs, add `admin_console_password = "yourpassword"` to `terraform.tfvars`.

### Optional: DNS (Route 53)

```hcl
enable_route53         = true
route53_zone_id        = "Z1234567890ABC"
domain_name            = "example.com"
admin_console_hostname = "admin"
tenant_hostname        = "chef360"
```

### Optional: Managed PostgreSQL (RDS)

```hcl
enable_rds          = true
rds_master_password = "replace-me"
```

### Optional: S3 Storage

```hcl
enable_s3        = true
s3_bucket_prefix = "chef360-prod"
```

---

## Topologies

Set `topology` in `terraform.tfvars` to one of:

| Topology | Nodes | Default Instance Type |
|---|---|---|
| `single_node` | 1 | m7i.4xlarge |
| `hyperconverged_ha` | 3 | m7i.4xlarge |
| `tiered_ha` | 6 (3 frontend + 3 backend) | c7i.2xlarge / m7i.4xlarge |
| `hyperscale_ha` | 9 (3 controller + 3 frontend + 3 backend) | m7i.xlarge / c7i.2xlarge / m7i.4xlarge |

Instance types can be overridden individually — see `variables.tf` for all `*_instance_type` variables.

---

## What Gets Created

- **VPC** — `10.50.0.0/16` (configurable) with public and private subnets across 3 AZs
- **Security group** — ingress rules for SSH (22), Admin Console (30000), API Gateway (31000), and optional Mailpit (31101)
- **EC2 instances** — Ubuntu nodes with IAM instance profile for SSM access
- **IAM role** — `AmazonSSMManagedInstanceCore` for Session Manager access without bastion
- **null_resource provisioner** — SSHes into the primary node to download and run the Chef 360 installer
- *(Optional)* Route 53 A records, RDS PostgreSQL instance, S3 buckets

---

## Outputs

After a successful `terraform apply`:

```bash
terraform output        # Shows public IPs, instance IDs, and Admin Console URL
```

Access the Admin Console at:
```
https://<primary-node-public-ip>:30000
```

---

## Security Notes

- **Never commit `terraform.tfvars`** — it contains your SSH key path and optionally your password. It is listed in `.gitignore`.
- **`terraform.tfstate` contains sensitive data** — use a remote backend (S3 + DynamoDB) for team or production use. See `environments/production/backend.hcl.example`.
- Set `ssh_cidr_blocks` and `admin_cidr_blocks` to your specific IP (`curl checkip.amazonaws.com`). Using `0.0.0.0/0` exposes your nodes to the internet.
- Root EBS volumes are encrypted by default.
- IMDSv2 is enforced on all instances (`http_tokens = "required"`).

---

## Re-running the Installer

If the Chef 360 installation provisioner needs to be re-run (e.g., after a failed apply):

```bash
terraform apply -replace=module.compute.null_resource.chef360_install
```

---

## Project Structure

```
.
├── environments/
│   └── production/
│       ├── backend.hcl.example     # Remote state backend config
│       └── terraform.tfvars.example
├── modules/
│   ├── compute/                    # EC2 instances + Chef 360 install provisioner
│   ├── dns/                        # Route 53 records
│   ├── network/                    # VPC, subnets, IGW, route tables
│   ├── rds/                        # Optional PostgreSQL RDS
│   ├── s3/                         # Optional S3 buckets
│   └── security/                   # Security groups and ingress rules
├── userdata/
│   └── chef360_prereqs.sh.tftpl    # EC2 bootstrap script (hostname, packages)
├── locals.tf                       # Topology node definitions
├── main.tf                         # Root module — wires all modules together
├── outputs.tf
├── providers.tf
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

---

## License

This project is provided as-is for provisioning Chef 360 infrastructure. Chef 360 itself is a commercial product by Progress Software — a valid license is required to use it.

