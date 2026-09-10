output "bucket_names" {
  value = { for bucket_key, bucket in aws_s3_bucket.this : bucket_key => bucket.bucket }
}
