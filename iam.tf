# All iam specific resources go in this file

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
# This policy will allow cloudfront the ability to pull objects out of S3 and cache them in edge locations. We are simply writing the policy here.
data "aws_iam_policy_document" "policy_for_giving_cloudfront_access_to_s3" {
  statement {
    actions = ["s3:GetObject"]
    # Since this policy references the S3 bucket resource, bucket will be created before this policy.
    # After creation, the arn of the bucket will be entered here.
    # Terraform resolves these dependencies such as which resources need to be created first using a dependency graph.
    resources = ["${aws_s3_bucket.bucket_for_static_content.arn}/*"]

    principals {
      type = "AWS"
      # This specifies that the cloudfront distribution origin access identity that will be able to access this S3 bucket.
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity_for_accessing_static_s3_bucket.iam_arn]
    }
  }
}