# Depending on environment and your needs, you can pass a different tfvars file into your command line.
# terraform plan -var-file="dev.tfvars"
# https://www.terraform.io/docs/language/values/variables.html

domain         = "codeislife.de" # change to your own domain
aws_region     = "us-east-1"
developer_name = "faisal.akhtar" # change to your own name
environment    = "dev"