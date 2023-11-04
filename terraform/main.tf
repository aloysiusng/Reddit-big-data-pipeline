#  S3 ============================================================================================================
resource "aws_s3_bucket" "social_media_data_bucket" {
  bucket = var.social_media_data_bucket
}
#  IAM ============================================================================================================
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_assume_role_policy.json
}

module "attach_policies_for_lambda_role" {
  source     = "./iam_policies"
  role_names = [aws_iam_role.lambda_role.name]
  policy_names = [
    "lambda-s3-access-policy",
    "lambda-access-policy",
  ]
  policy_descriptions = [
    "Policy for lambda to access S3",
    "Policy for lambda access",
  ]
  policy_documents = [
    data.aws_iam_policy_document.lambda_s3_policy.json,
    data.aws_iam_policy_document.lambda_policy.json,
  ]
}

# Lambda Scheduler IAM
resource "aws_iam_role" "eventbridge_role" {
  name               = "eventbridge_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_scheduler_role_assume_role_policy.json
}

#  Secrets Manager ============================================================================================================
resource "aws_secretsmanager_secret" "twitter" {
  name = "twitter"
}

#  Lambda layer ============================================================================================================
resource "aws_lambda_layer_version" "python_dependencies_layer" {
  filename   = "../backend/lambda/lambda_layer/python_dependencies.zip"
  layer_name = "python_dependencies_layer"
  compatible_runtimes = [
    "python3.9",
  ]
  source_code_hash = filebase64sha256("../backend/lambda/lambda_layer/python_dependencies.zip")
}

#  Lambda ============================================================================================================
module "demo_lambda" {
  source               = "./create_lambda"
  lambda_function_name = "test_lambda"
  lambda_file_name     = "../backend/lambda/test_lambda.zip"
  lambda_role_arn      = aws_iam_role.lambda_role.arn
  lambda_handler       = "test_lambda.lambda_handler"
  lambda_runtime       = "python3.9"
  scheduler_role_arn   = aws_iam_role.eventbridge_role.arn
  lambda_layers_arn    = [aws_lambda_layer_version.python_dependencies_layer.arn]
  # lambda_memory_size   = 128 # default is 128, max is 10240
  # lambda_timeout          = 900  # max timeout at 900 seconds i.e. 15 minutes
  # lambda_schedule          = "rate(14 days)" (default every 1 days)
  # scheduler_role_arn = "role arn for scheduler to assume"
  # environment_variables = {
  #   S3_BUCKET_NAME = aws_s3_bucket.team2_is459_data_bucket.id
  # }
}