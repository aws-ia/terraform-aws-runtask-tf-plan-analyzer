#####################################################################################
# LAMBDA
#####################################################################################

resource "terraform_data" "bootstrap" {
  provisioner "local-exec" {
    command = "cd ${path.module} && make build"
  }
}

################# Run task EventBridge ##################
resource "aws_lambda_function" "runtask_eventbridge" {
  function_name    = "${var.name_prefix}-runtask-eventbridge"
  description      = "HCP Terraform run task - EventBridge handler"
  role             = aws_iam_role.runtask_eventbridge.arn
  architectures    = local.lambda_architecture
  source_code_hash = data.archive_file.runtask_eventbridge.output_base64sha256
  filename         = data.archive_file.runtask_eventbridge.output_path
  handler          = "handler.lambda_handler"
  runtime          = local.lambda_python_runtime
  timeout          = local.lambda_default_timeout
  environment {
    variables = {
      HCP_TF_HMAC_SECRET_ARN = aws_secretsmanager_secret.runtask_hmac.arn
      HCP_TF_USE_WAF         = var.deploy_waf ? "True" : "False"
      HCP_TF_CF_SECRET_ARN   = var.deploy_waf ? aws_secretsmanager_secret.runtask_cloudfront[0].arn : null
      HCP_TF_CF_SIGNATURE    = var.deploy_waf ? local.cloudfront_sig_name : null
      EVENT_BUS_NAME         = var.event_bus_name
    }
  }
  tracing_config {
    mode = "Active"
  }
  reserved_concurrent_executions = local.lambda_reserved_concurrency
  #checkov:skip=CKV_AWS_116:not using DLQ
  #checkov:skip=CKV_AWS_117:VPC is not required
  #checkov:skip=CKV_AWS_173:non sensitive environment variables
  #checkov:skip=CKV_AWS_272:skip code-signing
}

resource "aws_lambda_function_url" "runtask_eventbridge" {
  function_name      = aws_lambda_function.runtask_eventbridge.function_name
  authorization_type = "AWS_IAM"
  #checkov:skip=CKV_AWS_258:auth set to none, validation hmac inside the lambda code
}

resource "aws_cloudwatch_log_group" "runtask_eventbridge" {
  name              = "/aws/lambda/${aws_lambda_function.runtask_eventbridge.function_name}"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
}

################# Run task request ##################
resource "aws_lambda_function" "runtask_request" {
  function_name                  = "${var.name_prefix}-runtask-request"
  description                    = "HCP Terraform run task - Request handler"
  role                           = aws_iam_role.runtask_request.arn
  architectures                  = local.lambda_architecture
  source_code_hash               = data.archive_file.runtask_request.output_base64sha256
  filename                       = data.archive_file.runtask_request.output_path
  handler                        = "handler.lambda_handler"
  runtime                        = local.lambda_python_runtime
  timeout                        = local.lambda_default_timeout
  reserved_concurrent_executions = local.lambda_reserved_concurrency
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      HCP_TF_ORG       = var.hcp_tf_org
      RUNTASK_STAGES   = join(",", var.runtask_stages)
      WORKSPACE_PREFIX = length(var.workspace_prefix) > 0 ? var.workspace_prefix : null
    }
  }
  #checkov:skip=CKV_AWS_116:not using DLQ
  #checkov:skip=CKV_AWS_117:VPC is not required
  #checkov:skip=CKV_AWS_173:no sensitive data in env var
  #checkov:skip=CKV_AWS_272:skip code-signing
}

resource "aws_cloudwatch_log_group" "runtask_request" {
  name              = "/aws/lambda/${aws_lambda_function.runtask_request.function_name}"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
}


################# Run task callback ##################
resource "aws_lambda_function" "runtask_callback" {
  function_name                  = "${var.name_prefix}-runtask-callback"
  description                    = "HCP Terraform run task - Callback handler"
  role                           = aws_iam_role.runtask_callback.arn
  architectures                  = local.lambda_architecture
  source_code_hash               = data.archive_file.runtask_callback.output_base64sha256
  filename                       = data.archive_file.runtask_callback.output_path
  handler                        = "handler.lambda_handler"
  runtime                        = local.lambda_python_runtime
  timeout                        = local.lambda_default_timeout
  reserved_concurrent_executions = local.lambda_reserved_concurrency
  tracing_config {
    mode = "Active"
  }
  #checkov:skip=CKV_AWS_116:not using DLQ
  #checkov:skip=CKV_AWS_117:VPC is not required
  #checkov:skip=CKV_AWS_272:skip code-signing
}

resource "aws_cloudwatch_log_group" "runtask_callback" {
  name              = "/aws/lambda/${aws_lambda_function.runtask_callback.function_name}"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
}

################# Run task Fulfillment ##################
resource "aws_lambda_function" "runtask_fulfillment" {
  function_name                  = "${var.name_prefix}-runtask-fulfillment"
  description                    = "HCP Terraform run task - Fulfillment handler"
  role                           = aws_iam_role.runtask_fulfillment.arn
  architectures                  = local.lambda_architecture
  source_code_hash               = data.archive_file.runtask_fulfillment.output_base64sha256
  filename                       = data.archive_file.runtask_fulfillment.output_path
  handler                        = "handler.lambda_handler"
  runtime                        = local.lambda_python_runtime
  timeout                        = local.lambda_default_timeout
  reserved_concurrent_executions = local.lambda_reserved_concurrency
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      CW_LOG_GROUP_NAME = "/aws/lambda/${var.name_prefix}-runtask-fulfillment"
    }
  }
  #checkov:skip=CKV_AWS_116:not using DLQ
  #checkov:skip=CKV_AWS_117:VPC is not required
  #checkov:skip=CKV_AWS_173:no sensitive data in env var
  #checkov:skip=CKV_AWS_272:skip code-signing
}

resource "aws_cloudwatch_log_group" "runtask_fulfillment" {
  name              = "/aws/lambda/${aws_lambda_function.runtask_fulfillment.function_name}"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
}

resource "aws_cloudwatch_log_group" "runtask_fulfillment_output" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
}

#####################################################################################
# EVENT BRIDGE
#####################################################################################

resource "aws_cloudwatch_event_rule" "runtask_rule" {
  name           = "${var.name_prefix}-runtask-rule"
  description    = "Rule to capture HCP Terraform run task events"
  event_bus_name = var.event_bus_name
  event_pattern = templatefile("${path.module}/templates/runtask_rule.tpl", {
    var_event_source   = var.event_source
    var_runtask_stages = jsonencode(var.runtask_stages)
  })
}

resource "aws_cloudwatch_event_target" "runtask_target" {
  rule           = aws_cloudwatch_event_rule.runtask_rule.id
  event_bus_name = var.event_bus_name
  arn            = aws_sfn_state_machine.runtask_states.arn
  role_arn       = aws_iam_role.runtask_rule.arn
}

#####################################################################################
# STATE MACHINE
#####################################################################################

resource "aws_sfn_state_machine" "runtask_states" {
  name     = "${var.name_prefix}-runtask-statemachine"
  role_arn = aws_iam_role.runtask_states.arn
  definition = templatefile("${path.module}/templates/runtask_states.asl.json", {
    resource_runtask_request     = aws_lambda_function.runtask_request.arn
    resource_runtask_fulfillment = aws_lambda_function.runtask_fulfillment.arn
    resource_runtask_callback    = aws_lambda_function.runtask_callback.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.runtask_states.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }
}

resource "aws_cloudwatch_log_group" "runtask_states" {
  name              = "/aws/state/${var.name_prefix}-runtask-statemachine"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
}

#####################################################################################
# SECRETS MANAGER
#####################################################################################

resource "random_uuid" "runtask_hmac" {}

resource "aws_secretsmanager_secret" "runtask_hmac" {
  #checkov:skip=CKV2_AWS_57:run terraform apply to rotate hmac
  name                    = "${var.name_prefix}-runtask-hmac"
  recovery_window_in_days = var.recovery_window
  kms_key_id              = aws_kms_key.runtask_key.arn
}

resource "aws_secretsmanager_secret_version" "runtask_hmac" {
  secret_id     = aws_secretsmanager_secret.runtask_hmac.id
  secret_string = random_uuid.runtask_hmac.result
}

resource "random_uuid" "runtask_cloudfront" {
  count = local.waf_deployment
}

resource "aws_secretsmanager_secret" "runtask_cloudfront" {
  #checkov:skip=CKV2_AWS_57:run terraform apply to rotate cloudfront secret
  count                   = local.waf_deployment
  name                    = "${var.name_prefix}-runtask_cloudfront"
  recovery_window_in_days = var.recovery_window
  kms_key_id              = aws_kms_key.runtask_key.arn
}

resource "aws_secretsmanager_secret_version" "runtask_cloudfront" {
  count         = local.waf_deployment
  secret_id     = aws_secretsmanager_secret.runtask_cloudfront[count.index].id
  secret_string = random_uuid.runtask_cloudfront[count.index].result
}

#####################################################################################
# KMS
#####################################################################################

resource "aws_kms_key" "runtask_key" {
  description         = "KMS key for run task integration"
  policy              = data.aws_iam_policy_document.runtask_key.json
  enable_key_rotation = true
}

# Assign an alias to the key
resource "aws_kms_alias" "runtask_key" {
  name          = "alias/runTask"
  target_key_id = aws_kms_key.runtask_key.key_id
}

resource "aws_kms_key" "runtask_waf" {
  count               = local.waf_deployment
  provider            = aws.cloudfront_waf
  description         = "KMS key for WAF"
  policy              = data.aws_iam_policy_document.runtask_waf[count.index].json
  enable_key_rotation = true
}

# Assign an alias to the key
resource "aws_kms_alias" "runtask_waf" {
  count         = local.waf_deployment
  provider      = aws.cloudfront_waf
  name          = "alias/runtask-WAF"
  target_key_id = aws_kms_key.runtask_waf[count.index].key_id
}

#####################################################################################
# CLOUDFRONT
#####################################################################################

module "runtask_cloudfront" {
  #checkov:skip=CKV2_AWS_42:custom domain name is optional

  count   = local.waf_deployment
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.2.1"

  comment             = "CloudFront for run task integration: ${var.name_prefix}"
  enabled             = true
  price_class         = "PriceClass_100"
  retain_on_delete    = false
  wait_for_deployment = true
  web_acl_id          = aws_wafv2_web_acl.runtask_waf[count.index].arn

  origin = {
    runtask_eventbridge = {
      domain_name = split("/", aws_lambda_function_url.runtask_eventbridge.function_url)[2]
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
      custom_header = var.deploy_waf ? [local.cloudfront_custom_header] : null
    }
  }

  default_cache_behavior = {
    target_origin_id       = "runtask_eventbridge"
    viewer_protocol_policy = "https-only"

    #SecurityHeadersPolicy: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html#managed-response-headers-policies-security
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"

    # caching disabled: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    origin_request_policy_id = aws_cloudfront_origin_request_policy.runtask_cloudfront[count.index].id
    use_forwarded_values     = false

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
  }

  viewer_certificate = {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1" # change it to TLSv1.2_2021
  }
}

resource "aws_cloudfront_origin_request_policy" "runtask_cloudfront" {
  count   = local.waf_deployment
  name    = "${var.name_prefix}-runtask_cloudfront_origin_request_policy"
  comment = "Forward all request headers except host"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "x-tfc-task-signature",
        "content-type",
        "user-agent",
        "x-amzn-trace-id"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

#####################################################################################
# WAF (OPTIONAL BUT RECOMMENDED)
#####################################################################################

resource "aws_wafv2_web_acl" "runtask_waf" {
  count    = local.waf_deployment
  provider = aws.cloudfront_waf

  name        = "${var.name_prefix}-runtask_waf_acl"
  description = "Run task WAF with simple rate base rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-base-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = local.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-runtask_request_rate"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.waf_managed_rule_set
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-runtask_request_${rule.value.metric_suffix}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-runtask_waf_acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudwatch_log_group" "runtask_waf" {
  count             = local.waf_deployment
  provider          = aws.cloudfront_waf
  name              = "aws-waf-logs-${var.name_prefix}-runtask_waf_acl"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_waf[count.index].arn
}

resource "aws_wafv2_web_acl_logging_configuration" "runtask_waf" {
  count                   = local.waf_deployment
  provider                = aws.cloudfront_waf
  log_destination_configs = [aws_cloudwatch_log_group.runtask_waf[count.index].arn]
  resource_arn            = aws_wafv2_web_acl.runtask_waf[count.index].arn
  redacted_fields {
    single_header {
      name = "x-tfc-task-signature"
    }
  }
}
