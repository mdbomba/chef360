locals {
  public_ports = concat([30000, 31000, 31050], var.enable_mailpit_port ? [31101] : [])

  admin_rules = {
    for rule in flatten([
      for cidr in var.admin_cidr_blocks : [
        for port in local.public_ports : {
          key  = "admin-${replace(cidr, "/", "-")}-${port}"
          cidr = cidr
          port = port
        }
      ]
    ]) : rule.key => rule
  }

  ssh_rules = {
    for rule in flatten([
      for cidr in var.ssh_cidr_blocks : [
        {
          key  = "ssh-${replace(cidr, "/", "-")}"
          cidr = cidr
        }
      ]
    ]) : rule.key => rule
  }

  cluster_tcp_ports = var.multi_node ? [2380, 6443, 9091, 9443, 10249, 10250, 10256, 30000] : []
  cluster_udp_ports = var.multi_node ? [4789] : []
}

resource "aws_security_group" "chef360" {
  name        = "${var.name_prefix}-chef360"
  description = "Chef 360 platform security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-chef360"
  })
}

resource "aws_vpc_security_group_ingress_rule" "admin_ports" {
  for_each = local.admin_rules

  security_group_id = aws_security_group.chef360.id
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.port
  ip_protocol       = "tcp"
  to_port           = each.value.port
  description       = "Chef 360 public service port ${each.value.port}"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = local.ssh_rules

  security_group_id = aws_security_group.chef360.id
  cidr_ipv4         = each.value.cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "SSH access"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_tcp" {
  for_each = toset([for port in local.cluster_tcp_ports : tostring(port)])

  security_group_id            = aws_security_group.chef360.id
  from_port                    = tonumber(each.value)
  ip_protocol                  = "tcp"
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.chef360.id
  description                  = "Chef 360 intra-cluster TCP port ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_udp" {
  for_each = toset([for port in local.cluster_udp_ports : tostring(port)])

  security_group_id            = aws_security_group.chef360.id
  from_port                    = tonumber(each.value)
  ip_protocol                  = "udp"
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.chef360.id
  description                  = "Chef 360 intra-cluster UDP port ${each.value}"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.chef360.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound traffic"
}
