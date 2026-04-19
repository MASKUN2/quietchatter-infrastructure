resource "aws_s3_bucket" "controlplane_config" {
  bucket = "quietchatter-controlplane-config"

  tags = {
    Name = "quietchatter-controlplane-config"
  }
}

resource "aws_s3_bucket_public_access_block" "controlplane_config" {
  bucket = aws_s3_bucket.controlplane_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "controlplane_config_bucket" {
  value = aws_s3_bucket.controlplane_config.bucket
}
