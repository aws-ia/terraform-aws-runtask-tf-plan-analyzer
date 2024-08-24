data "aws_region" "current_region" {}

data "aws_region" "cloudfront_region" {
  provider = aws.cloudfront_waf
}

data "aws_caller_identity" "current_account" {}

data "aws_partition" "current_partition" {}

data "aws_iam_policy" "lambda_basic_execution_managed_policy" {
  name = "AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy" "bedrock_full_access_managed_policy" {
  name = "AmazonBedrockFullAccess"
}

data "aws_iam_policy" "ec2_readonly_managed_policy" {
  name = "AmazonEC2ReadOnlyAccess"
}