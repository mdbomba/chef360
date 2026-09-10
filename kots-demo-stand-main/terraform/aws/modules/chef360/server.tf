data "template_file" "script" {
    template = "${file("${path.module}/scripts/chef-360.tpl")}"
    
    vars = {
        kots = "${data.template_file.kots.rendered}"
        tenant_subdomain = var.tenant_subdomain
        tenant_tld = var.tenant_tld
        authorization_code = var.authorization_code
        console_password = var.console_password
    }
}

data "template_file" "kots" {
    template = "${file("${path.module}/scripts/kots.tpl")}"

    vars = {
        tenant_tld = var.tenant_tld
        tenant_subdomain = var.tenant_subdomain
        admin_first_name = var.admin_first_name
        admin_last_name = var.admin_last_name
        admin_email = var.admin_email
        tenant_name = var.tenant_name
        org_unit_name = var.org_unit_name
    }
}

data "template_cloudinit_config" "chef-360" {
    gzip = false
    base64_encode = false
    part {
        filename = "init.cfg"
        content_type = "text/cloud-config"
        content = data.template_file.script.rendered
    }
}

data "template_file" "windows-client" {
    template = "${file("${path.module}/scripts/windows-client.tpl")}"
}

resource "aws_instance" "chef_360" {
    ami = data.aws_ami.ubuntu.id
    # instance_type = "t2.2xlarge"
    instance_type = "m5.4xlarge"
    key_name = var.aws_key_pair_name
    subnet_id = var.subnet_id
    vpc_security_group_ids = [ aws_security_group.chef_360.id ]
    private_ip = "10.0.1.5"
    user_data = data.template_cloudinit_config.chef-360.rendered
    ebs_optimized = true
    root_block_device {
        delete_on_termination = true
        volume_size = 300
        volume_type = "gp2"
    }  
    tags = var.tags
}

resource "aws_instance" "chef_client_1" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.small"
    key_name = "dslanec_client"
    subnet_id = var.subnet_id
    vpc_security_group_ids = [ aws_security_group.chef_client.id ]
    private_ip = "10.0.1.10"
    ebs_optimized = true
    root_block_device {
        delete_on_termination = true
        volume_size = 80
        volume_type = "gp2"
    }  
    tags = var.tags
}

resource "aws_instance" "chef_client_2" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.small"
    key_name = "dslanec_client"
    subnet_id = var.subnet_id
    vpc_security_group_ids = [ aws_security_group.chef_client.id ]
    private_ip = "10.0.1.20"
    ebs_optimized = true
    root_block_device {
        delete_on_termination = true
        volume_size = 80
        volume_type = "gp2"
    }  
    tags = var.tags
}

resource "aws_instance" "chef_client_3" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.small"
    key_name = "dslanec_client"
    subnet_id = var.subnet_id
    vpc_security_group_ids = [ aws_security_group.chef_client.id ]
    private_ip = "10.0.1.30"
    ebs_optimized = true
    root_block_device {
        delete_on_termination = true
        volume_size = 80
        volume_type = "gp2"
    }  
    tags = var.tags
}