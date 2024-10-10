#####################################################################################
# KMS
#####################################################################################

resource "aws_kms_key" "runtask_key" {
  description         = "KMS key for run task integration"
  policy              = data.aws_iam_policy_document.runtask_key.json
  enable_key_rotation = true
  tags                = local.combined_tags
}

# Assign an alias to the key
resource "aws_kms_alias" "runtask_key" {
  name          = "alias/runTaskKey"
  target_key_id = aws_kms_key.runtask_key.key_id
}

resource "aws_kms_key" "runtask_waf" {
  count               = local.waf_deployment
  provider            = aws.cloudfront_waf
  description         = "KMS key for WAF"
  policy              = data.aws_iam_policy_document.runtask_waf[count.index].json
  enable_key_rotation = true
  tags                = local.combined_tags
}

# Assign an alias to the key
resource "aws_kms_alias" "runtask_waf" {
  count         = local.waf_deployment
  provider      = aws.cloudfront_waf
  name          = "alias/runtaskWAF"
  target_key_id = aws_kms_key.runtask_waf[count.index].key_id
}
