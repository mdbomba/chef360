variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in tags and naming."
  type        = string
  default     = "production"
}

variable "name_prefix" {
  description = "Prefix used for all created resources."
  type        = string
  default     = "chef360"
}

variable "topology" {
  description = "Chef 360 deployment topology."
  type        = string
  default     = "single_node"

  validation {
    condition = contains([
      "single_node",
      "hyperconverged_ha",
      "tiered_ha",
      "hyperscale_ha",
    ], var.topology)
    error_message = "topology must be one of single_node, hyperconverged_ha, tiered_ha, or hyperscale_ha."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for Chef 360 nodes."
  type        = list(string)
  default     = ["10.50.0.0/24", "10.50.1.0/24", "10.50.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for managed services such as RDS."
  type        = list(string)
  default     = ["10.50.10.0/24", "10.50.11.0/24", "10.50.12.0/24"]
}

variable "availability_zones" {
  description = "Optional explicit list of availability zones. If empty, Terraform selects enough AZs automatically."
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name used for SSH access."
  type        = string
  default     = "Abinash_us_east_1"
}

variable "node_ami_id" {
  description = "AMI ID for Chef 360 nodes. Use a supported Linux image."
  type        = string
  default     = "ami-005fc0f236362e99f"
}

variable "assign_public_ip" {
  description = "Whether Chef 360 instances should get public IP addresses."
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH on Chef 360 nodes."
  type        = list(string)
  default     = []
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to reach the Chef 360 Admin Console, API Gateway, RabbitMQ, and optional Mailpit."
  type        = list(string)
  default     = []
}

variable "enable_mailpit_port" {
  description = "Whether to expose the optional Mailpit port 31101."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Base domain for DNS records, for example example.com."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_route53" {
  description = "Whether to create Route 53 records for the platform."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID used for DNS records."
  type        = string
  default     = null
  nullable    = true
}

variable "admin_console_hostname" {
  description = "Hostname label for the Chef 360 Admin Console record."
  type        = string
  default     = "admin"
}

variable "tenant_hostname" {
  description = "Hostname label for the tenant entry point record."
  type        = string
  default     = "chef360"
}

variable "single_node_instance_type" {
  description = "Instance type used for single-node deployments."
  type        = string
  default     = "m7i.4xlarge"
}

variable "hyperconverged_instance_type" {
  description = "Instance type used for hyperconverged HA nodes."
  type        = string
  default     = "m7i.4xlarge"
}

variable "tiered_frontend_instance_type" {
  description = "Instance type used for tiered HA frontend nodes."
  type        = string
  default     = "c7i.2xlarge"
}

variable "tiered_backend_instance_type" {
  description = "Instance type used for tiered HA controller/backend nodes."
  type        = string
  default     = "m7i.4xlarge"
}

variable "hyperscale_controller_instance_type" {
  description = "Instance type used for hyperscale HA controller nodes."
  type        = string
  default     = "m7i.xlarge"
}

variable "hyperscale_frontend_instance_type" {
  description = "Instance type used for hyperscale HA frontend nodes."
  type        = string
  default     = "c7i.2xlarge"
}

variable "hyperscale_backend_instance_type" {
  description = "Instance type used for hyperscale HA backend nodes."
  type        = string
  default     = "m7i.4xlarge"
}

variable "root_volume_type" {
  description = "EBS volume type used for root disks."
  type        = string
  default     = "gp3"
}

variable "user_data_extra" {
  description = "Optional extra shell commands appended to the EC2 bootstrap script."
  type        = string
  default     = ""
}

variable "enable_rds" {
  description = "Whether to provision Amazon RDS for PostgreSQL."
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class for PostgreSQL when enable_rds is true."
  type        = string
  default     = "db.m7g.large"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB for the PostgreSQL instance."
  type        = number
  default     = 100
}

variable "rds_db_name" {
  description = "Database name for the PostgreSQL instance."
  type        = string
  default     = "postgres"
}

variable "rds_master_username" {
  description = "Master username for the PostgreSQL instance."
  type        = string
  default     = "postgres"
}

variable "rds_master_password" {
  description = "Master password for the PostgreSQL instance. Required when enable_rds is true."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "enable_s3" {
  description = "Whether to provision S3 buckets for Chef 360 job data and logs."
  type        = bool
  default     = false
}

variable "s3_bucket_prefix" {
  description = "Prefix used for S3 bucket names when enable_s3 is true."
  type        = string
  default     = null
  nullable    = true
}

variable "common_tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "ssh_private_key_path" {
  description = "Local path to the .pem private key file used to SSH into Chef 360 nodes."
  type        = string
}

variable "admin_console_password" {
  description = "Password for the Chef 360 Admin Console set during installation. Will be prompted interactively."
  type        = string
  default     = "Admin1234"
}
