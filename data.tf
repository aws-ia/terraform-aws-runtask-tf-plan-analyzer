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

#####################################################################################
# LAMBDA
#####################################################################################

data "archive_file" "runtask_eventbridge" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/runtask_eventbridge/site-packages/"
  output_path = "${path.module}/lambda/runtask_eventbridge.zip"
  depends_on  = [terraform_data.bootstrap]
}

data "archive_file" "runtask_request" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/runtask_request/site-packages/"
  output_path = "${path.module}/lambda/runtask_request.zip"
  depends_on  = [terraform_data.bootstrap]
}

data "archive_file" "runtask_callback" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/runtask_callback/site-packages"
  output_path = "${path.module}/lambda/runtask_callback.zip"
  depends_on  = [terraform_data.bootstrap]
}

data "archive_file" "runtask_fulfillment" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/runtask_fulfillment/site-packages"
  output_path = "${path.module}/lambda/runtask_fulfillment.zip"
  depends_on  = [terraform_data.bootstrap]
}

data "archive_file" "runtask_edge" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/runtask_edge/site-packages"
  output_path = "${path.module}/lambda/runtask_edge.zip"
  depends_on  = [terraform_data.bootstrap]
}