# https://www.terraform.io/docs/language/providers/requirements.html
# Configure AWS as a required provider. This will let terraform know which provider to install and which version.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
      #version = "3.62.0"
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs 
# Configure the AWS provider. This is provider specific configurations. For example, AWS requires a region value.
provider "aws" {
  # We are using the aws_region value passed as a variable. The variable definition can be found in variables.tf
  # The specific value to which this variable will be set is found in the dev.tfvars file.
  # You can use a different var file such as prod.tfvar for different environments.
  region = var.aws_region
}

# https://www.terraform.io/docs/language/values/locals.html
# Locals can be used to specify local values in this file that you don't want to declare in vars. 
locals {
  s3_origin_id = "bucket-for-static-content-origin-id"
  tags = {
    Owner       = var.developer_name
    Environment = var.environment
  }
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
# This policy will allow cloudfront the ability to pull objects out of S3 and cache them in edge locations. We are simply writing the policy here.
data "aws_iam_policy_document" "policy_for_giving_cloudfront_access_to_s3" {
  statement {
    actions = ["s3:GetObject"]
    # Since this policy references this S3 bucket resources, it will be created before this policy.
    # After creation, the arn of the bucket will be entered here.
    # Terraform resolves these dependencies such as which resources need to be created first.
    resources = ["${aws_s3_bucket.bucket_for_static_content.arn}/*"]

    principals {
      type = "AWS"
      # This specifies that the cloudfront distribution origin access identity that will be able to access this S3 bucket.
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity_for_accessing_static_s3_bucket.iam_arn]
    }
  }
}

resource "aws_s3_bucket" "bucket_for_static_content" {
  # https://www.terraform.io/docs/configuration-0-11/interpolation.html
  # I am using string interpolation along with functions to create a unique s3 bucket name.
  bucket = "static-content-${split(".", var.domain)[0]}-${var.aws_region}-${var.environment}"
  force_destroy = true # be careful with this options as it will delete the items in the bucket before destorying the bucket
  acl    = "private"
  # referencing local tags declared above
  tags = local.tags
}

# # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object
# # This will upload all static content to the S3 bucket
# resource "aws_s3_bucket_object" "static_content" {
#   for_each = fileset("./static_content/", "*")

#   bucket = aws_s3_bucket.bucket_for_static_content.id
#   key    = each.value
#   source = "./static_content/${each.value}"
#   # etag makes the file update when it changes; see https://stackoverflow.com/questions/56107258/terraform-upload-file-to-s3-on-every-apply
#   etag = filemd5("./static_content/${each.value}")
# }

resource "null_resource" "remove_and_upload_to_s3" {
  provisioner "local-exec" {
    command = "aws s3 sync ./static_content/ s3://${aws_s3_bucket.bucket_for_static_content.id}"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_identity
# This is the origin access identity of the cloudfront distribution
resource "aws_cloudfront_origin_access_identity" "origin_access_identity_for_accessing_static_s3_bucket" {
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy
# This bucket policy will be applied to the S3 bucket so that cloudfront will be able to access the S3 bucket.
resource "aws_s3_bucket_policy" "bucket_policy_for_allowing_access_to_cloudfront" {
  bucket = aws_s3_bucket.bucket_for_static_content.id
  policy = data.aws_iam_policy_document.policy_for_giving_cloudfront_access_to_s3.json
}

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
  default_root_object = "index.html"

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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
# This is the certificate that will be protecting the distribution.
resource "aws_acm_certificate" "cert_protecting_distribution" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"] # so that cert can be used for sub domain such as www.codeislife.de
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
  tags = local.tags
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
# This validation ensures that the route 53 records propogate before proceeding
resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = aws_acm_certificate.cert_protecting_distribution.arn
  validation_record_fqdns = [for record in aws_route53_record.domain_records_for_route53 : record.fqdn]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
# Read above how to enter records validating that you own that domain.
resource "aws_route53_record" "domain_records_for_route53" {
  for_each = {
    for dvo in aws_acm_certificate.cert_protecting_distribution.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.your_domain.zone_id

}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
# Create the NS records for your domain
resource "aws_route53_record" "your_domain_ns_record" {
  allow_overwrite = true
  name            = var.domain
  ttl             = 172800
  type            = "NS"
  zone_id         = aws_route53_zone.your_domain.zone_id

  records = [
    aws_route53_zone.your_domain.name_servers[0],
    aws_route53_zone.your_domain.name_servers[1],
    aws_route53_zone.your_domain.name_servers[2],
    aws_route53_zone.your_domain.name_servers[3],
  ]
}

#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
# record to point www to cloudfront distribution
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.your_domain.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = "5"
  records = [aws_cloudfront_distribution.cloudfront_distribution_fronting_s3_content.domain_name]
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record#alias
# ALias record for poisting the apex zone to the CloudFront distribution
resource "aws_route53_record" "a_record_alias" {
  zone_id = aws_route53_zone.your_domain.zone_id
  name    = "codeislife.de"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloudfront_distribution_fronting_s3_content.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_distribution_fronting_s3_content.hosted_zone_id
    evaluate_target_health = false
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone
# You must purchase the domain before you can create the zone in route 53
# Notice the prevent destory. The reason is that if you destory the zone, recreation requires time for entries to propogate throguh the world wide DNS.
# You will have to import the route 53 zone using 
# terraform import -var-file="dev.tfvars" aws_route53_zone.your_domain Z1042347Z048PGTJD0W2
# You can remove the resource from being tracked by terraform using 
# terraform state rm 'aws_route53_zone.your_domain'
resource "aws_route53_zone" "your_domain" {
  name = var.domain
  tags = local.tags
  # lifecycle {
  #   prevent_destroy = true
  # }
}