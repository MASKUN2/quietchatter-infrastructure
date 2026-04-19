resource "aws_s3_bucket" "infra_assets" {
  bucket = "quietchatter-infra-assets"

  tags = {
    Name = "quietchatter-infra-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "infra_assets" {
  bucket = aws_s3_bucket.infra_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "infra_assets_bucket_name" {
  value = aws_s3_bucket.infra_assets.bucket
}

output "infra_assets_bucket_arn" {
  value = aws_s3_bucket.infra_assets.arn
}
