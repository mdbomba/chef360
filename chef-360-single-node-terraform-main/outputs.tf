output "topology" {
  description = "Selected Chef 360 topology."
  value       = var.topology
}

output "instance_ids" {
  description = "EC2 instance IDs keyed by node name."
  value       = module.compute.instance_ids
}

output "private_ips" {
  description = "Private IP addresses keyed by node name."
  value       = module.compute.private_ips
}

output "public_ips" {
  description = "Public IP addresses keyed by node name."
  value       = module.compute.public_ips
}

output "admin_console_fqdn" {
  description = "Admin Console DNS name if a domain was configured."
  value       = local.admin_console_fqdn
}

output "tenant_fqdn" {
  description = "Tenant DNS name if a domain was configured."
  value       = local.tenant_fqdn
}

output "rds_writer_endpoint" {
  description = "Writer endpoint for the optional PostgreSQL RDS instance."
  value       = var.enable_rds ? module.rds[0].writer_endpoint : null
}

output "s3_bucket_names" {
  description = "Optional S3 buckets created for Chef 360 job data and logs."
  value       = var.enable_s3 ? module.s3[0].bucket_names : {}
}
