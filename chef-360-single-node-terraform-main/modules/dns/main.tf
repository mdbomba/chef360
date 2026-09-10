resource "aws_route53_record" "a_records" {
  for_each = var.records

  zone_id = var.zone_id
  name    = each.key
  type    = "A"
  ttl     = 300
  records = [each.value]
}
