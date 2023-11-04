resource "aws_lambda_function" "lambda_function" {
  function_name = var.lambda_function_name
  filename      = var.lambda_file_name
  role          = var.lambda_role_arn
  handler       = var.lambda_handler

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  layers = var.lambda_layers_arn

  environment {
    variables = var.environment_variables
  }
}

# lambda function logging
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}
# invoke lambda daily via event 

resource "aws_scheduler_schedule" "lambda_schedule" {
  name                = "${var.lambda_function_name}-lambda-scheduler"
  description         = "Schedule for ${var.lambda_function_name}"
  schedule_expression = var.lambda_schedule

  flexible_time_window {
    maximum_window_in_minutes = 60
    mode                      = "FLEXIBLE"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:lambda:invoke"
    role_arn = var.scheduler_role_arn
    input    = jsonencode({
      FunctionName = var.lambda_function_name
      InvocationType = "Event"
      Payload = ""
    })
  }
}