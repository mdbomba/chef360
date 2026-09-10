locals {
  buckets = {
    courier_job_data = "${var.bucket_prefix}-courier-data"
    general_logs     = "${var.bucket_prefix}-general-logs"
    audit_logs       = "${var.bucket_prefix}-audit-logs"
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket = each.value

  tags = merge(var.tags, {
    Name = each.value
    Use  = each.key
  })
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
