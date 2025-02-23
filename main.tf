resource "random_string" "solution_prefix" {
  length  = 4
  special = false
  upper   = false
}

#####################################################################################
# EVENT BRIDGE
#####################################################################################

resource "aws_cloudwatch_event_rule" "runtask_rule" {
  name           = "${local.solution_prefix}-runtask-rule"
  description    = "Rule to capture HCP Terraform run task events"
  event_bus_name = var.event_bus_name
  event_pattern = templatefile("${path.module}/templates/runtask_rule.tpl", {
    var_event_source           = var.event_source
    var_runtask_stages         = jsonencode(var.runtask_stages)
    var_event_rule_detail_type = local.solution_prefix
  })
  tags = local.combined_tags
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
  name     = "${local.solution_prefix}-runtask-statemachine"
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

  tags = local.combined_tags
}

resource "aws_cloudwatch_log_group" "runtask_states" {
  name              = "/aws/vendedlogs/states/${local.solution_prefix}-runtask-statemachine"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = aws_kms_key.runtask_key.arn
  tags              = local.combined_tags
}
