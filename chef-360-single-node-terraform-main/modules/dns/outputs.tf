output "record_fqdns" {
  value = [for record in aws_route53_record.a_records : record.fqdn]
}
