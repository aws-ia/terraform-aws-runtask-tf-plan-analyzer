locals {
  lambda_managed_policies = [
    data.aws_iam_policy.lambda_basic_execution_managed_policy.arn,
  ]

  lambda_bedrock_managed_policies = [
    data.aws_iam_policy.bedrock_full_access_managed_policy.arn,
    data.aws_iam_policy.ec2_readonly_managed_policy.arn
  ]

  lambda_reserved_concurrency = var.lambda_reserved_concurrency
  lambda_default_timeout      = var.lambda_default_timeout
  lambda_python_runtime       = var.lambda_python_runtime
  lambda_architecture         = [var.lambda_architecture]

  cloudwatch_log_group_name = var.cloudwatch_log_group_name

  waf_deployment = var.deploy_waf ? 1 : 0
  waf_rate_limit = var.waf_rate_limit

  cloudfront_sig_name = "x-cf-sig"
  cloudfront_custom_header = {
    name  = local.cloudfront_sig_name
    value = var.deploy_waf ? aws_secretsmanager_secret_version.runtask_cloudfront[0].secret_string : null
  }
}