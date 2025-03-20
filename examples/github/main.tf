#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

data "aws_region" "current" {}

data "tfe_organization" "hcp_tf_org" {
  name = var.hcp_tf_org
}

resource "aws_secretsmanager_secret" "github_api_token" {
  #checkov:skip=CKV2_AWS_57:run terraform apply to rotate api key
  #checkov:skip=CKV_AWS_149:skipping KMS based encryption as it's just an example setup
  name = "tf_ai_github_api_token"
}

resource "aws_secretsmanager_secret_version" "github_api_token" {
  secret_id     = aws_secretsmanager_secret.github_api_token.id
  secret_string = var.github_api_token
}

module "hcp_tf_run_task" {
  source               = "../.."
  aws_region           = data.aws_region.current.name
  hcp_tf_org           = data.tfe_organization.hcp_tf_org.name
  run_task_iam_roles   = var.tf_run_task_logic_iam_roles
  github_api_token_arn = aws_secretsmanager_secret_version.github_api_token.arn
  deploy_waf           = true
}

resource "tfe_organization_run_task" "bedrock_plan_analyzer" {
  enabled      = true
  organization = data.tfe_organization.hcp_tf_org.name
  url          = module.hcp_tf_run_task.runtask_url
  hmac_key     = module.hcp_tf_run_task.runtask_hmac
  name         = "Bedrock-TF-Plan-Analyzer"
  description  = "Analyze TF plan using Amazon Bedrock"
}
