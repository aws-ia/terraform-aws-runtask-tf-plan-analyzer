#####################################################################################
# CLOUDFRONT
#####################################################################################

module "runtask_cloudfront" {
  #checkov:skip=CKV2_AWS_42:custom domain name is optional

  count   = local.waf_deployment
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.0"

  comment             = "CloudFront for run task integration: ${local.solution_prefix}"
  enabled             = true
  price_class         = "PriceClass_100"
  retain_on_delete    = false
  wait_for_deployment = true
  web_acl_id          = aws_wafv2_web_acl.runtask_waf[count.index].arn

  create_origin_access_control = true
  origin_access_control = {
    lambda_oac = {
      description      = "CloudFront OAC to Lambda"
      origin_type      = "lambda"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    runtask_eventbridge = {
      domain_name = split("/", aws_lambda_function_url.runtask_eventbridge.function_url)[2]
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
      origin_access_control = "lambda_oac"
      custom_header         = var.deploy_waf ? [local.cloudfront_custom_header] : null
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

    lambda_function_association = {
      # This function will append header x-amz-content-sha256 to allow OAC to authenticate with Lambda Function URL
      viewer-request = {
        lambda_arn   = aws_lambda_function.runtask_edge.qualified_arn
        include_body = true
      }
    }
  }

  viewer_certificate = {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1" # change it to TLSv1.2_2021
  }

  tags = local.combined_tags
}

resource "aws_cloudfront_origin_request_policy" "runtask_cloudfront" {
  count   = local.waf_deployment
  name    = "${local.solution_prefix}-runtask_cloudfront_origin_request_policy"
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

  name        = "${local.solution_prefix}-runtask_waf_acl"
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
      metric_name                = "${local.solution_prefix}-runtask_request_rate"
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
        metric_name                = "${local.solution_prefix}-runtask_request_${rule.value.metric_suffix}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.solution_prefix}-runtask_waf_acl"
    sampled_requests_enabled   = true
  }

  tags = local.combined_tags
}

resource "aws_cloudwatch_log_group" "runtask_waf" {
  count             = local.waf_deployment
  provider          = aws.cloudfront_waf
  name              = "aws-waf-logs-${local.solution_prefix}-runtask_waf_acl"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_waf[count.index].arn
  tags              = local.combined_tags
}

resource "aws_cloudwatch_log_resource_policy" "runtask_waf" {
  count           = local.waf_deployment
  policy_document = data.aws_iam_policy_document.runtask_waf_log[count.index].json
  policy_name     = "aws-waf-logs-${local.solution_prefix}-runtask_waf_acl"
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
