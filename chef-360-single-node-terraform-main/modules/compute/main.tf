data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name_prefix}-chef360-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-chef360-ssm"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-chef360-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "nodes" {
  for_each = var.instances

  ami                         = var.ami_id
  instance_type               = each.value.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_ids[each.value.subnet_index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = aws_iam_instance_profile.this.name
  user_data = templatefile(var.user_data_template_path, {
    hostname     = each.value.hostname
    role         = each.value.role
    extra_script = var.user_data_extra
  })

  root_block_device {
    volume_size           = each.value.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name          = each.value.hostname
    Role          = each.value.role
    X-Contact     = "abinash.prusty@progress.com"
    X-Dept        = "PS"
    X-Environment = "PS"
    X-Project     = "testingWithTerraform"
    X-Sleep       = "off"
    X-Customer    = "Prod-Spec-Team"
    CreatedBy     = "Abinash.Prusty@progress.com"
  })
}

locals {
  primary_node_key = tolist(sort(keys(var.instances)))[0]
}

resource "null_resource" "chef360_install" {
  depends_on = [aws_instance.nodes]

  connection {
    type        = "ssh"
    host        = aws_instance.nodes[local.primary_node_key].public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "30m"
  }

  provisioner "remote-exec" {
  inline = [
    "sudo curl -f 'https://appservice.chef360.chef.io/embedded/chef-360/unstable/v1.7.1' -H 'Authorization: 2eV8kEsfQs6LoiVsZWci3R9qQ7S' -o /tmp/chef-360-unstable.tgz",
    "sudo tar -xvzf /tmp/chef-360-unstable.tgz -C /tmp",
    "cd /tmp && sudo ./chef-360 install --license license.yaml --admin-console-password '${var.admin_console_password}'"
  ]
}
}
