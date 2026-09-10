provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = "chef360"
        Environment = var.environment
        ManagedBy   = "terraform"
      },
      var.common_tags,
    )
  }
}
