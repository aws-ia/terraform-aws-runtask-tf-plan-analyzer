################# IAM for run task EventBridge ##################
resource "aws_iam_role" "runtask_eventbridge" {
  name               = "${var.name_prefix}-runtask-eventbridge"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
}

resource "aws_iam_role_policy_attachment" "runtask_eventbridge" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_eventbridge.name
  policy_arn = local.lambda_managed_policies[count.index]
}

resource "aws_iam_role_policy" "runtask_eventbridge" {
  name = "${var.name_prefix}-runtask-eventbridge-policy"
  role = aws_iam_role.runtask_eventbridge.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-eventbridge-lambda-role-policy.tpl", {
    data_aws_region          = data.aws_region.current_region.name
    data_aws_account_id      = data.aws_caller_identity.current_account.account_id
    data_aws_partition       = data.aws_partition.current_partition.partition
    var_event_bus_name       = var.event_bus_name
    resource_runtask_secrets = var.deploy_waf ? [aws_secretsmanager_secret.runtask_hmac.arn, aws_secretsmanager_secret.runtask_cloudfront[0].arn] : [aws_secretsmanager_secret.runtask_hmac.arn]
  })
}

################# IAM for run task request ##################
resource "aws_iam_role" "runtask_request" {
  name               = "${var.name_prefix}-runtask-request"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
}

resource "aws_iam_role_policy_attachment" "runtask_request" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_request.name
  policy_arn = local.lambda_managed_policies[count.index]
}

################# IAM for run task callback ##################
resource "aws_iam_role" "runtask_callback" {
  name               = "${var.name_prefix}-runtask-callback"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
}

resource "aws_iam_role_policy_attachment" "runtask_callback" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_callback.name
  policy_arn = local.lambda_managed_policies[count.index]
}

################# IAM for run task fulfillment ##################
resource "aws_iam_role" "runtask_fulfillment" {
  name                = "${var.name_prefix}-runtask-fulfillment"
  assume_role_policy  = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
}

resource "aws_iam_role_policy_attachment" "runtask_fulfillment_basic_attachment" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_fulfillment.name
  policy_arn = local.lambda_managed_policies[count.index]
}

resource "aws_iam_role_policy_attachment" "runtask_fulfillment_additional_attachment" {
  count      = length(var.run_task_iam_roles)
  role       = aws_iam_role.runtask_fulfillment.name
  policy_arn = var.run_task_iam_roles[count.index]
}

resource "aws_iam_role_policy" "runtask_fulfillment" {
  name = "${var.name_prefix}-runtask-fulfillment-policy"
  role = aws_iam_role.runtask_fulfillment.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-fulfillment-lambda-role-policy.tpl", {
    data_aws_region      = data.aws_region.current_region.name
    data_aws_account_id  = data.aws_caller_identity.current_account.account_id
    data_aws_partition   = data.aws_partition.current_partition.partition
    local_log_group_name = local.cloudwatch_log_group_name
  })
}

################# IAM for run task StateMachine ##################
resource "aws_iam_role" "runtask_states" {
  name               = "${var.name_prefix}-runtask-statemachine"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/states.tpl", { none = "none" })
}

resource "aws_iam_role_policy" "runtask_states" {
  name = "${var.name_prefix}-runtask-statemachine-policy"
  role = aws_iam_role.runtask_states.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-state-role-policy.tpl", {
    data_aws_region     = data.aws_region.current_region.name
    data_aws_account_id = data.aws_caller_identity.current_account.account_id
    data_aws_partition  = data.aws_partition.current_partition.partition
    var_name_prefix     = var.name_prefix
  })
}


################# IAM for run task EventBridge rule ##################
resource "aws_iam_role" "runtask_rule" {
  name               = "${var.name_prefix}-runtask-rule"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/events.tpl", { none = "none" })
}

resource "aws_iam_role_policy" "runtask_rule" {
  name = "${var.name_prefix}-runtask-rule-policy"
  role = aws_iam_role.runtask_rule.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-rule-role-policy.tpl", {
    resource_runtask_states = aws_sfn_state_machine.runtask_states.arn
  })
}

################# IAM for the Cloudwatch log groups ##################
data "aws_iam_policy_document" "runtask_key" {
  #checkov:skip=CKV_AWS_109:KMS management permission by IAM user
  #checkov:skip=CKV_AWS_111:wildcard permission required for kms key
  #checkov:skip=CKV_AWS_356:wildcard permission required for kms key
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:${data.aws_partition.current_partition.id}:iam::${data.aws_caller_identity.current_account.account_id}:root"
      ]
    }
  }
  statement {
    sid    = "Allow Service CloudWatchLogGroup"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:Describe",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current_region.name}.amazonaws.com"
      ]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:${data.aws_partition.current_partition.id}:logs:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_account.account_id}:log-group:/aws/lambda/${var.name_prefix}*",
        "arn:${data.aws_partition.current_partition.id}:logs:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_account.account_id}:log-group:/aws/state/${var.name_prefix}*",
        "arn:${data.aws_partition.current_partition.id}:logs:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_account.account_id}:log-group:${var.cloudwatch_log_group_name}*"
      ]
    }
  }
  statement {
    sid    = "Allow Service Secrets Manager"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:Describe"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.runtask_eventbridge.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "secretsmanager.${data.aws_region.current_region.name}.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values = [
        data.aws_caller_identity.current_account.account_id
      ]
    }
  }
}

################# IAM for WAF (Optional) ##################
data "aws_iam_policy_document" "runtask_waf" {
  #checkov:skip=CKV_AWS_109:KMS management permission by IAM user
  #checkov:skip=CKV_AWS_111:wildcard permission required for kms key
  #checkov:skip=CKV_AWS_356:wildcard permission required for kms key
  count    = local.waf_deployment
  provider = aws.cloudfront_waf
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:${data.aws_partition.current_partition.id}:iam::${data.aws_caller_identity.current_account.account_id}:root"
      ]
    }
  }
  statement {
    sid    = "Allow Service CloudWatchLogGroup"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:Describe",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.cloudfront_region.name}.amazonaws.com"
      ]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:${data.aws_partition.current_partition.id}:logs:${data.aws_region.cloudfront_region.name}:${data.aws_caller_identity.current_account.account_id}:log-group:aws-waf-logs-${var.name_prefix}-runtask_waf_acl*"
      ]
    }
  }
}
