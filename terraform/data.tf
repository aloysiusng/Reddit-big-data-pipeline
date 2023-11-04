#  Lambda IAM ============================================================================================================
data "aws_iam_policy_document" "lambda_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_s3_policy" {
  statement {
    actions   = ["s3:*", "s3-object-lambda:*"]
    resources = ["${aws_s3_bucket.social_media_data_bucket.arn}/input/*", "${aws_s3_bucket.social_media_data_bucket.arn}/output/*"]
  }
}

data "aws_iam_policy_document" "cloudwatch_policy" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }
}
data "aws_iam_policy_document" "lambda_secrets_manager_access_policy" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:ListSecrets"]
    resources = [aws_secretsmanager_secret.twitter.arn]
  }
}

#  Event bridge IAM ============================================================================================================
data "aws_iam_policy_document" "lambda_scheduler_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}