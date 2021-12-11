# All s3 specific resources and specifications are in this file

locals {
  static_files = {
    "index"              = { filename = "index.html", source = "static_content/index.html", content_type = "text/html", },
    "simpleChat"         = { filename = "js/simpleChat.js", source = "static_content/js/simpleChat.js", content_type = "text/javascript", },
    "jquery"             = { filename = "js/jquery.min.js", source = "static_content/js/jquery.min.js", content_type = "text/javascript", },
    "bootstrapmin"       = { filename = "js/bootstrap.min.js", source = "static_content/js/bootstrap.min.js", content_type = "text/javascript", },
    "bootstrapbundle"    = { filename = "js/bootstrap.bundle.min.js", source = "static_content/js/bootstrap.bundle.min.js", content_type = "text/javascript", },
    "bootstrapbundlemap" = { filename = "js/bootstrap.bundle.min.js.map", source = "static_content/js/bootstrap.bundle.min.js.map", content_type = "application/json", },
    "female"             = { filename = "img/person-female.png", source = "static_content/img/person-female.png", content_type = "image/png", },
    "male"               = { filename = "img/administrator-male.png", source = "static_content/img/administrator-male.png", content_type = "image/png", },
    "fontawsome"         = { filename = "fonts/fontawesome-webfont.woff", source = "static_content/fonts/fontawesome-webfont.woff", content_type = "font/woff", },
    "simplechatcss"      = { filename = "css/simpleChat.css", source = "static_content/css/simpleChat.css", content_type = "text/css", },
    "fontawsomecss"      = { filename = "css/font-awesome.css", source = "static_content/css/font-awesome.css", content_type = "text/css", },
    "bootstrapmincss"    = { filename = "css/bootstrap.min.css", source = "static_content/css/bootstrap.min.css", content_type = "text/css", },
    "bootstrapmincssmap" = { filename = "css/bootstrap.min.css.map", source = "static_content/css/bootstrap.min.css.map", content_type = "application/json", }
  }
}

# https://www.terraform.io/docs/configuration-0-11/interpolation.html
resource "aws_s3_bucket" "bucket_for_static_content" {
  # I am using string interpolation along with functions to create a unique s3 bucket name.
  bucket        = "static-content-${split(".", var.domain)[0]}-${var.aws_region}-${var.environment}"
  force_destroy = true # be careful with this options as it will delete the items in the bucket before destorying the bucket
  acl           = "private"
  # referencing local tags declared above
  tags = local.tags
}

# https://binx.io/blog/2020/06/17/create-multiple-resources-at-once-with-terraform-for_each/
# Not official docs but great blog on how to use for each to creat multiple resources.
# We are creating multiple s3 files in the static content s3 bucket.
resource "aws_s3_bucket_object" "static_content" {
  for_each     = local.static_files
  bucket       = aws_s3_bucket.bucket_for_static_content.id #reference the s3 bucket where these files will be hosted
  key          = each.value.filename # for each file, fill out the properties
  source       = each.value.source
  etag         = filemd5("${each.value.source}") # this ensures that file will be replaced on s3 if it is changed locally
  content_type = each.value.content_type
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy
# This bucket policy will be applied to the S3 bucket so that cloudfront will be able to access the S3 bucket. Here are are applying the policy we wrote above.
resource "aws_s3_bucket_policy" "bucket_policy_for_allowing_access_to_cloudfront" {
  bucket = aws_s3_bucket.bucket_for_static_content.id
  policy = data.aws_iam_policy_document.policy_for_giving_cloudfront_access_to_s3.json
}