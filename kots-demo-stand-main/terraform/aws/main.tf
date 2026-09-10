terraform {
  required_version = "1.9.8"
}

provider "aws" {
    region = "${var.aws_region}"
    profile = "${var.aws_profile}"
    shared_credentials_files = "${var.aws_credentials_file}"
}

module "network" {
    source = "./modules/network"
    aws_region = "${var.aws_region}"
    tags = {
        Name          = "${var.tag_name}"
        X-Dept        = "${var.tag_dept}"
        X-Customer    = "${var.tag_customer}"
        X-Project     = "${var.tag_project}"
        X-Contact     = "${var.tag_contact}"
        X-Application = "${var.tag_application}"
        X-TTL         = "${var.tag_ttl}"
    }
}

module "chef_360" {
    source = "./modules/chef360"
    vpc_id = module.network.vpc_id
    subnet_id = module.network.subnet_id
    aws_key_pair_name = var.aws_key_pair_name
    authorization_code = var.authorization_code
    tenant_subdomain = var.tenant_subdomain
    tenant_tld = var.tenant_tld
    console_password = var.console_password
    admin_first_name = var.admin_first_name
    admin_last_name = var.admin_last_name
    admin_email = var.admin_email
    tenant_name = var.tenant_name
    org_unit_name = var.org_unit_name
    tags = {
        Name          = "${var.tag_name}"
        X-Dept        = "${var.tag_dept}"
        X-Customer    = "${var.tag_customer}"
        X-Project     = "${var.tag_project}"
        X-Contact     = "${var.tag_contact}"
        X-Application = "${var.tag_application}"
        X-TTL         = "${var.tag_ttl}"
    }
}