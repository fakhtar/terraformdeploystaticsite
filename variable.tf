# https://www.terraform.io/docs/language/values/variables.html

variable "domain" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "regex_replace_chars" {
  type    = string
  default = "/[^a-zA-Z0-9-]/"
}
variable "developer_name" {
  type = string
}
variable "environment" {
  type = string
}