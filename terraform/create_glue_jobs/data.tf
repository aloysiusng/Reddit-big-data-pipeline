data "local_file" "glue_job_file" {
  filename = var.path_to_glue_job_file
  # "../glue/merge_data_source_job.py"
}