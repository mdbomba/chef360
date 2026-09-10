output "instance_ids" {
  value = { for node_key, instance in aws_instance.nodes : node_key => instance.id }
}

output "private_ips" {
  value = { for node_key, instance in aws_instance.nodes : node_key => instance.private_ip }
}

output "public_ips" {
  value = { for node_key, instance in aws_instance.nodes : node_key => instance.public_ip }
}
