resource "aws_bedrock_guardrail" "runtask_fulfillment" {
  name                      = "${local.solution_prefix}-guardrails"
  blocked_input_messaging   = "Unfortunately we are unable to provide response for this input"
  blocked_outputs_messaging = "Unfortunately we are unable to provide response for this input"
  description               = "Basic Bedrock Guardrail for sensitive info exfiltration"

  # detect and filter harmful user inputs and FM-generated outputs
  content_policy_config {
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "HATE"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "INSULTS"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "MISCONDUCT"
    }
    filters_config {
      input_strength  = "NONE"
      output_strength = "NONE"
      type            = "PROMPT_ATTACK"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "SEXUAL"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "VIOLENCE"
    }
  }

  # block / mask potential PII information
  sensitive_information_policy_config {
    pii_entities_config {
      action = "BLOCK"
      type   = "DRIVER_ID"
    }
    pii_entities_config {
      action = "BLOCK"
      type   = "PASSWORD"
    }
    pii_entities_config {
      action = "ANONYMIZE"
      type   = "EMAIL"
    }
    pii_entities_config {
      action = "ANONYMIZE"
      type   = "USERNAME"
    }
    pii_entities_config {
      action = "BLOCK"
      type   = "AWS_ACCESS_KEY"
    }
    pii_entities_config {
      action = "BLOCK"
      type   = "AWS_SECRET_KEY"
    }
  }

  # block select word / profanity
  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }

  tags = local.combined_tags
}

resource "aws_bedrock_guardrail_version" "runtask_fulfillment" {
  guardrail_arn = aws_bedrock_guardrail.runtask_fulfillment.guardrail_arn
  description   = "Initial version"
}
