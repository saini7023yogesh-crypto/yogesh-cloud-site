terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "yogesh-tfstate-k7q2x9"
    key          = "portfolio/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}
    

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "project" {
  type    = string
  default = "yogesh-portfolio"
}

provider "aws" {
  region = var.region
}

# Bucket names are global, so add a random suffix
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project}-${random_id.suffix.hex}"
}

# 1. Private S3 bucket (force_destroy lets `terraform destroy` empty it)
resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. OAC: the "pass" CloudFront uses to read the bucket
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3. CloudFront distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    # Managed "CachingDisabled": updates show instantly while learning.
    # Later switch to Managed-CachingOptimized: 658327ea-f89d-4fab-a63d-7e88639e58f6
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 4. Bucket policy: only this distribution may read objects
data "aws_iam_policy_document" "site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# 5. Upload the page with the correct Content-Type (no more text-only page!)
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/site/index.html"
  etag         = filemd5("${path.module}/site/index.html")
  content_type = "text/html; charset=utf-8"
}

output "site_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "bucket_name" {
  value = aws_s3_bucket.site.id
}

