data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "./modules/network"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.selected_azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.common_tags
}

module "security" {
  source = "./modules/security"

  name_prefix         = var.name_prefix
  vpc_id              = module.network.vpc_id
  ssh_cidr_blocks     = var.ssh_cidr_blocks
  admin_cidr_blocks   = var.admin_cidr_blocks
  multi_node          = local.multi_node
  enable_mailpit_port = var.enable_mailpit_port
  tags                = var.common_tags
}

module "compute" {
  source = "./modules/compute"

  name_prefix             = var.name_prefix
  ami_id                  = var.node_ami_id
  key_name                = var.key_name
  subnet_ids              = module.network.public_subnet_ids
  security_group_ids      = [module.security.chef360_security_group_id]
  instances               = local.nodes
  assign_public_ip        = var.assign_public_ip
  root_volume_type        = var.root_volume_type
  user_data_template_path = "${path.root}/userdata/chef360_prereqs.sh.tftpl"
  user_data_extra         = var.user_data_extra
  tags                    = var.common_tags
  ssh_private_key_path    = var.ssh_private_key_path
  admin_console_password  = var.admin_console_password
}

module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "./modules/rds"

  name_prefix               = var.name_prefix
  subnet_ids                = module.network.private_subnet_ids
  vpc_id                    = module.network.vpc_id
  allowed_security_group_id = module.security.chef360_security_group_id
  db_name                   = var.rds_db_name
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage
  master_username           = var.rds_master_username
  master_password           = var.rds_master_password
  tags                      = var.common_tags
}

module "s3" {
  count  = var.enable_s3 ? 1 : 0
  source = "./modules/s3"

  bucket_prefix = coalesce(var.s3_bucket_prefix, var.name_prefix)
  tags          = var.common_tags
}

module "dns" {
  count  = var.enable_route53 && var.route53_zone_id != null && var.domain_name != null ? 1 : 0
  source = "./modules/dns"

  zone_id = var.route53_zone_id
  records = merge(
    {
      for node_key, fqdn in local.node_fqdns : fqdn => module.compute.public_ips[node_key]
    },
    local.admin_console_fqdn == null ? {} : {
      (local.admin_console_fqdn) = module.compute.public_ips[local.primary_node_key]
    },
    local.tenant_fqdn == null ? {} : {
      (local.tenant_fqdn) = module.compute.public_ips[local.primary_node_key]
    },
  )
}
