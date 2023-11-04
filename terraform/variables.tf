# retrieve variables from terraform.tfvars
variable "AWS_ACCESS_KEY_ID" {
  type = string
}
variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}
variable "AWS_ACCOUNT_ID" {
  type = string
}
variable "AWS_REGION" {
  type = string
}


variable "social_media_data_bucket" {
  type = string
  default = "social-media-data-bucket"
}