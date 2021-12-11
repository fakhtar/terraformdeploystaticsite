
# All ACM and certificate related resources and configs go in this file

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
# This is the certificate that will be protecting the Cloudfront distribution.
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
# This validation ensures that the route 53 records propogate before proceeding.
resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = aws_acm_certificate.cert_protecting_distribution.arn
  validation_record_fqdns = [for record in aws_route53_record.domain_records_for_route53 : record.fqdn]
}