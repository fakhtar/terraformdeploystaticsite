# https://www.terraform.io/docs/language/providers/requirements.html
# By convention these blocks belong in main.tf. Set AWS as a required provider. This will let terraform know which provider to install and which version.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs 
# Configure the AWS provider. This is provider specific configurations. For example, AWS requires a region value.
provider "aws" {
  # We are using the aws_region value passed as a variable. The variable definition can be found in variable.tf
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
