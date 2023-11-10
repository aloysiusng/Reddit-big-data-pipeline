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
  type    = string
  default = "aloy-social-media-data-bucket"
}
variable "glue_scripts_bucket" {
  type    = string
  default = "aloy-glue-scripts-bucket"
}
variable "social_media_glue_catalog_database" {
  type    = string
  default = "social_media_glue_catalog_database"
}