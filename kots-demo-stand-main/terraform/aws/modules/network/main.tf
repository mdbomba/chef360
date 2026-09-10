resource "aws_vpc" "core-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    tags = var.tags
}

resource "aws_internet_gateway" "core-gateway" {
    vpc_id = "${aws_vpc.core-vpc.id}"
    tags = {
      Name = "core-gateway"
    }
}

resource "aws_route" "core-internet-access" {
    route_table_id = "${aws_vpc.core-vpc.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.core-gateway.id}"
}

resource "aws_subnet" "core-subnet-a" {
    vpc_id = "${aws_vpc.core-vpc.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${var.aws_region}a"
    tags = {
        Name = "core-subnet-a"
    }
  
}