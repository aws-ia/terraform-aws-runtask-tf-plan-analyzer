################# IAM for run task Lambda@Edge ##################
resource "aws_iam_role" "runtask_edge" {
  name               = "${local.solution_prefix}-runtask-edge"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda_edge.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy_attachment" "runtask_edge" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_edge.name
  policy_arn = local.lambda_managed_policies[count.index]
}

################# IAM for run task EventBridge ##################
resource "aws_iam_role" "runtask_eventbridge" {
  name               = "${local.solution_prefix}-runtask-eventbridge"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy_attachment" "runtask_eventbridge" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_eventbridge.name
  policy_arn = local.lambda_managed_policies[count.index]
}

resource "aws_iam_role_policy" "runtask_eventbridge" {
  name = "${local.solution_prefix}-runtask-eventbridge-policy"
  role = aws_iam_role.runtask_eventbridge.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-eventbridge-lambda-role-policy.tpl", {
    data_aws_region          = data.aws_region.current_region.region
    data_aws_account_id      = data.aws_caller_identity.current_account.account_id
    data_aws_partition       = data.aws_partition.current_partition.partition
    var_event_bus_name       = var.event_bus_name
    resource_runtask_secrets = var.deploy_waf ? [aws_secretsmanager_secret.runtask_hmac.arn, aws_secretsmanager_secret.runtask_cloudfront[0].arn] : [aws_secretsmanager_secret.runtask_hmac.arn]
  })
}

################# IAM for run task request ##################
resource "aws_iam_role" "runtask_request" {
  name               = "${local.solution_prefix}-runtask-request"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy_attachment" "runtask_request" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_request.name
  policy_arn = local.lambda_managed_policies[count.index]
}

################# IAM for run task callback ##################
resource "aws_iam_role" "runtask_callback" {
  name               = "${local.solution_prefix}-runtask-callback"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy_attachment" "runtask_callback" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_callback.name
  policy_arn = local.lambda_managed_policies[count.index]
}

################# IAM for run task fulfillment ##################
resource "aws_iam_role" "runtask_fulfillment" {
  name               = "${local.solution_prefix}-runtask-fulfillment"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/lambda.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy_attachment" "runtask_fulfillment_basic_attachment" {
  count      = length(local.lambda_managed_policies)
  role       = aws_iam_role.runtask_fulfillment.name
  policy_arn = local.lambda_managed_policies[count.index]
}

resource "aws_iam_role_policy_attachment" "runtask_fulfillment_bedrock_attachment" {
  count      = length(local.lambda_bedrock_managed_policies)
  role       = aws_iam_role.runtask_fulfillment.name
  policy_arn = local.lambda_bedrock_managed_policies[count.index]
}

resource "aws_iam_role_policy_attachment" "runtask_fulfillment_additional_attachment" {
  # Customer can add additional permissions
  count      = length(var.run_task_iam_roles)
  role       = aws_iam_role.runtask_fulfillment.name
  policy_arn = var.run_task_iam_roles[count.index]
}

resource "aws_iam_role_policy" "runtask_fulfillment" {
  name = "${local.solution_prefix}-runtask-fulfillment-policy"
  role = aws_iam_role.runtask_fulfillment.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-fulfillment-lambda-role-policy.tpl", {
    data_aws_region      = data.aws_region.current_region.region
    data_aws_account_id  = data.aws_caller_identity.current_account.account_id
    data_aws_partition   = data.aws_partition.current_partition.partition
    local_log_group_name = local.cloudwatch_log_group_name
  })
}

################# IAM for run task StateMachine ##################
resource "aws_iam_role" "runtask_states" {
  name               = "${local.solution_prefix}-runtask-statemachine"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/states.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy" "runtask_states" {
  name = "${local.solution_prefix}-runtask-statemachine-policy"
  role = aws_iam_role.runtask_states.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-state-role-policy.tpl", {
    data_aws_region     = data.aws_region.current_region.region
    data_aws_account_id = data.aws_caller_identity.current_account.account_id
    data_aws_partition  = data.aws_partition.current_partition.partition
    var_name_prefix     = var.name_prefix
  })
}


################# IAM for run task EventBridge rule ##################
resource "aws_iam_role" "runtask_rule" {
  name               = "${local.solution_prefix}-runtask-rule"
  assume_role_policy = templatefile("${path.module}/templates/trust-policies/events.tpl", { none = "none" })
  tags               = local.combined_tags
}

resource "aws_iam_role_policy" "runtask_rule" {
  name = "${local.solution_prefix}-runtask-rule-policy"
  role = aws_iam_role.runtask_rule.id
  policy = templatefile("${path.module}/templates/role-policies/runtask-rule-role-policy.tpl", {
    resource_runtask_states = aws_sfn_state_machine.runtask_states.arn
  })
}