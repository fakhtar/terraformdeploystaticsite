# All variable specifications go in this file. You must declare a var before using it.
# https://www.terraform.io/docs/language/values/variables.html

variable "domain" {
  type = string
}
variable "aws_region" {
  type = string
}

variable "developer_name" {
  type = string
}
variable "environment" {
  type = string
}