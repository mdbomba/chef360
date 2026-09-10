output "vpc_id" {
  value = "${aws_vpc.core-vpc.id}"
}

output "subnet_id" {
  value = "${aws_subnet.core-subnet-a.id}"
}