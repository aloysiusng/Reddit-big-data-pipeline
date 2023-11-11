resource "aws_cloudwatch_log_group" "glue_job_log_group" {
  name              = "${var.job_name}_log_group"
  retention_in_days = 14
}
# add glue job script to s3 -
resource "aws_s3_object" "glue_job_script" {
  bucket                 = var.s3_bucket_id
  key                    = "${var.job_name}.py"
  source                 = data.local_file.glue_job_file.filename
  content_type           = "text/x-python"
  server_side_encryption = "AES256"
}
resource "aws_glue_job" "glue_job" {
  name         = var.job_name
  role_arn     = var.iam_role_arn
  glue_version = "4.0"
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.s3_bucket_id}/${var.job_name}.py"
  }
  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_job_log_group.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = ""
  }
}
resource "aws_glue_trigger" "glue_job_conditional_trigger" {
  name = "${var.job_name}_conditional_trigger"
  type = "CONDITIONAL"
  actions {
    job_name = aws_glue_job.glue_job.name
  }
  predicate {
    conditions {
      crawler_name = var.depends_on_crawler_name
      crawl_state  = "SUCCEEDED"
    }
  }
}
