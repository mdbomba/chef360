resource "aws_security_group" "chef_360" {
    name = "chef_360_${random_id.instance_id.hex}"
    description = "Chef 360 Server"
    vpc_id = var.vpc_id
}

//////////////////////////
// Base Linux Rules
resource "aws_security_group_rule" "Ingress_allow_22_tcp_workstation" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "linux_egress_allow_0-65535_all" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    security_group_id = "${aws_security_group.chef_360.id}"
}

//////////////////////////
// Base Windows Rules

//////////////////////////
// Chef 360 Rules
resource "aws_security_group_rule" "Ingress_allow_30000_tcp_workstation" {
    type = "ingress"
    from_port = 30000
    to_port = 30000
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31000_tcp_workstation" {
    type = "ingress"
    from_port = 31000
    to_port = 31000
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31100_tcp_workstation" {
    type = "ingress"
    from_port = 31100
    to_port = 31100
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_30000_tcp_client" {
    type = "ingress"
    from_port = 30000
    to_port = 30000
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31000_tcp_client" {
    type = "ingress"
    from_port = 31000
    to_port = 31000
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31050_tcp_client" {
    type = "ingress"
    from_port = 31050
    to_port = 31050
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31100_tcp_client" {
    type = "ingress"
    from_port = 31101
    to_port = 31101
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

//////////////////////
resource "aws_security_group_rule" "Ingress_allow_31000_tcp_client_1" {
    type = "ingress"
    from_port = 31000
    to_port = 31000
    protocol = "tcp"
    cidr_blocks = ["${aws_instance.chef_client_1.public_ip}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31050_tcp_client_1" {
    type = "ingress"
    from_port = 31050
    to_port = 31050
    protocol = "tcp"
    cidr_blocks = ["${aws_instance.chef_client_1.public_ip}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31000_tcp_client_2" {
    type = "ingress"
    from_port = 31000
    to_port = 31000
    protocol = "tcp"
    cidr_blocks = ["${aws_instance.chef_client_2.public_ip}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31050_tcp_client_2" {
    type = "ingress"
    from_port = 31050
    to_port = 31050
    protocol = "tcp"
    cidr_blocks = ["${aws_instance.chef_client_2.public_ip}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31000_tcp_client_3" {
    type = "ingress"
    from_port = 31000
    to_port = 31000
    protocol = "tcp"
    cidr_blocks = ["${aws_instance.chef_client_3.public_ip}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}

resource "aws_security_group_rule" "Ingress_allow_31050_tcp_client_3" {
    type = "ingress"
    from_port = 31050
    to_port = 31050
    protocol = "tcp"
    cidr_blocks = ["${aws_instance.chef_client_3.public_ip}/32"]
    security_group_id = "${aws_security_group.chef_360.id}"
}



// Client
resource "aws_security_group" "chef_client" {
    name = "chef_client_${random_id.instance_id.hex}"
    description = "Chef client"
    vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "Ingress_allow_22_tcp_client" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_client.id}"
}

resource "aws_security_group_rule" "Ingress_allow_3389_tcp_client" {
    type = "ingress"
    from_port = 3389
    to_port = 3389
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    security_group_id = "${aws_security_group.chef_client.id}"
}

resource "aws_security_group_rule" "Ingress_allow_5985_tcp_client" {
    type = "ingress"
    from_port = 5985
    to_port = 5985
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    security_group_id = "${aws_security_group.chef_client.id}"
}

resource "aws_security_group_rule" "Ingress_allow_5986_tcp_client" {
    type = "ingress"
    from_port = 5986
    to_port = 5986
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    security_group_id = "${aws_security_group.chef_client.id}"
}

resource "aws_security_group_rule" "Ingress_allow_22_tcp_client_360" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    security_group_id = "${aws_security_group.chef_client.id}"
}

resource "aws_security_group_rule" "linux_egress_allow_0-65535_all_client" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    security_group_id = "${aws_security_group.chef_client.id}"
}