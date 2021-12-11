# All cloudfront specific resources and config go in this file.

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
# This cloudfront distribution will be caching the content from the source s3 bucket into edge locations.
resource "aws_cloudfront_distribution" "cloudfront_distribution_fronting_s3_content" {
  origin {
    domain_name = aws_s3_bucket.bucket_for_static_content.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    # Specifies that S3 will be the origin for this cloudfront distribution.
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity_for_accessing_static_s3_bucket.cloudfront_access_identity_path
    }
  }
  enabled             = true
  default_root_object = "index.html" #This will be first page served up. when someone hits this distribution.

  # Notice that instead of manually creating all the infrastrucutre, we can specify in code what we need so we forget nothing.
  aliases = [var.domain, "www.${var.domain}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }
  # using the cheapest price call for cloudfront. 
  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert_protecting_distribution.arn
    ssl_support_method  = "sni-only"
  }

  tags = local.tags
  # This explicit dependency is added so that this distribution is created only after validation of the ACM cert.
  depends_on = [
    aws_acm_certificate_validation.certificate_validation
  ]
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_identity
# This is the origin access identity of the cloudfront distribution
resource "aws_cloudfront_origin_access_identity" "origin_access_identity_for_accessing_static_s3_bucket" {
}