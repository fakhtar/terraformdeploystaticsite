# All reoute 53 specifics resources, records and configs go in this file

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
# You will have to import the route 53 zone using the command below. Replce the zone id at the end with your own.
# terraform import -var-file="dev.tfvars" aws_route53_zone.your_domain Z1042347Z048PGTJD0W2
# You can remove the resource from being tracked by terraform using 
# terraform state rm 'aws_route53_zone.your_domain'
resource "aws_route53_zone" "your_domain" {
  name = var.domain
  tags = local.tags
  lifecycle {
    prevent_destroy = true # Notice the prevent destory. The reason is that if you destory the zone, recreation requires time for entries to propogate throguh the world wide DNS.
  }
}