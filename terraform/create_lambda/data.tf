data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../backend/lambda/${var.lambda_function_name}"
  output_path = "../backend/lambda/${var.lambda_function_name}.zip"
}