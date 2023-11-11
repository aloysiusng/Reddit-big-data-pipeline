variable "job_name" {
  type = string
  //merge_data_source_job
}

variable "s3_bucket_id" {
  type = string
  //aws_s3_bucket.glue_scripts_bucket.id
}

variable "iam_role_arn" {
  type = string
  //aws_iam_role.glue_role.arn
}
variable "depends_on_crawler_name" {
  type        = string
  description = "which crawler it depends on, give the name"
}

variable "path_to_glue_job_file" {
  type        = string
  description = "path to glue job file e.g. ../backend/glue/x.py"
}