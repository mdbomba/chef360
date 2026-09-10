output "chef_360_ip" {
  value = "${aws_instance.chef_360.public_ip}"
}

output "chef_client_1_ip" {
  value = "${aws_instance.chef_client_1.public_ip}"
}

output "chef_client_2_ip" {
  value = "${aws_instance.chef_client_2.public_ip}"
}

output "chef_client_3_ip" {
  value = "${aws_instance.chef_client_3.public_ip}"
}