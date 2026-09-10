data "aws_route53_zone" "selected" {
  name = "${var.tenant_tld}."
}

resource "aws_route53_record" "chef_360" {
  zone_id = data.aws_route53_zone.selected.id
  name    = var.tenant_subdomain
  type    = "A"
  ttl     = "30"
  records = [aws_instance.chef_360.public_ip]
}