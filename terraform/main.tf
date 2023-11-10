#  S3 ============================================================================================================
resource "aws_s3_bucket" "social_media_data_bucket" {
  bucket = var.social_media_data_bucket
}
resource "aws_s3_bucket" "glue_scripts_bucket" {
  bucket = var.glue_scripts_bucket
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
    "lambda-secrets-manager-access-policy",
    "lambda-cloudwatch-policy"
  ]
  policy_descriptions = [
    "Policy for lambda to access S3",
    "Policy for lambda access",
    "Policy for lambda to access secrets manager",
    "Policy for lambda to access cloudwatch"
  ]
  policy_documents = [
    data.aws_iam_policy_document.lambda_s3_policy.json,
    data.aws_iam_policy_document.lambda_policy.json,
    data.aws_iam_policy_document.lambda_secrets_manager_access_policy.json,
    data.aws_iam_policy_document.cloudwatch_policy.json,
  ]
}

# Lambda Scheduler IAM
resource "aws_iam_role" "eventbridge_role" {
  name               = "eventbridge_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_scheduler_role_assume_role_policy.json
}

# glue iam
resource "aws_iam_role" "glue_role" {
  name               = "glue_role"
  assume_role_policy = data.aws_iam_policy_document.glue_role_assume_role_policy.json
}
module "attach_policies_for_glue" {
  source     = "./iam_policies"
  role_names = [aws_iam_role.glue_role.name]
  policy_names = [
    "glue_access_policy",
    "glue_s3_access_policy",
    "glue_cloudwatch_access_policy"
  ]
  policy_descriptions = [
    "Policy for lambda to access glue",
    "Policy for glue to access S3",
    "Policy for glue to access cloudwatch"
  ]
  policy_documents = [
    data.aws_iam_policy_document.glue_policy.json,
    data.aws_iam_policy_document.glue_s3_policy.json,
    data.aws_iam_policy_document.cloudwatch_policy.json,
  ]
}

#  Secrets Manager ============================================================================================================
resource "aws_secretsmanager_secret" "reddit" {
  name = "reddit"
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
  lambda_function_name = "scrape_reddit"
  lambda_file_name     = "../backend/lambda/scrape_reddit.zip"
  lambda_role_arn      = aws_iam_role.lambda_role.arn
  lambda_handler       = "scrape_reddit.lambda_handler"
  lambda_runtime       = "python3.9"
  scheduler_role_arn   = aws_iam_role.eventbridge_role.arn
  lambda_layers_arn    = [aws_lambda_layer_version.python_dependencies_layer.arn]
  lambda_memory_size   = 3008           # default is 128, max is 10240
  lambda_timeout       = 900            # max timeout at 900 seconds i.e. 15 minutes
  lambda_schedule      = "rate(1 days)" # (default every 1 days)
  environment_variables = {
    S3_BUCKET_NAME = aws_s3_bucket.social_media_data_bucket.id
  }
}


# Glue====================================================================================================
# glue catalog
resource "aws_glue_catalog_database" "social_media_glue_catalog_database" {
  name = var.social_media_glue_catalog_database

}
resource "aws_glue_crawler" "reddit_posts_crawler" {
  name          = "reddit_posts_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.social_media_glue_catalog_database.name
  schedule      = "cron(20 0 * * ? *)" // Daily at 12:20 AM UTC 
  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }
  s3_target {
    path = "s3://${var.social_media_data_bucket}/input/scrape_reddit_posts"
  }
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}
resource "aws_glue_crawler" "reddit_comments_crawler" {
  name          = "reddit_comments_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.social_media_glue_catalog_database.name
  schedule      = "cron(20 0 * * ? *)" // Daily at 12:20 AM UTC 
  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }
  s3_target {
    path = "s3://${var.social_media_data_bucket}/input/scrape_reddit_comments"
  }
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}
