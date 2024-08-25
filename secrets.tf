#####################################################################################
# SECRETS MANAGER
#####################################################################################

resource "random_uuid" "runtask_hmac" {}

resource "aws_secretsmanager_secret" "runtask_hmac" {
  #checkov:skip=CKV2_AWS_57:run terraform apply to rotate hmac
  name                    = "${local.solution_prefix}-runtask-hmac"
  recovery_window_in_days = var.recovery_window
  kms_key_id              = aws_kms_key.runtask_key.arn
  tags                    = local.combined_tags
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
  name                    = "${local.solution_prefix}-runtask_cloudfront"
  recovery_window_in_days = var.recovery_window
  kms_key_id              = aws_kms_key.runtask_key.arn
  tags                    = local.combined_tags
}

resource "aws_secretsmanager_secret_version" "runtask_cloudfront" {
  count         = local.waf_deployment
  secret_id     = aws_secretsmanager_secret.runtask_cloudfront[count.index].id
  secret_string = random_uuid.runtask_cloudfront[count.index].result
}