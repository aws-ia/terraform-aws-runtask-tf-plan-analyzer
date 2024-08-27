resource "awscc_bedrock_guardrail" "runtask_fulfillment" {
  name                      = "${local.solution_prefix}-guardrail"
  blocked_input_messaging   = "Unfortunately we are unable to provide response for this input"
  blocked_outputs_messaging = "Unfortunately we are unable to provide response for this input"
  description               = "Basic Bedrock Guardrail for sensitive info exfiltration"

  # detect and filter harmful user inputs and FM-generated outputs
  content_policy_config = {
    filters_config = [
      {
        input_strength  = "HIGH"
        output_strength = "HIGH"
        type            = "SEXUAL"
      },
      {
        input_strength  = "HIGH"
        output_strength = "HIGH"
        type            = "VIOLENCE"
      },
      {
        input_strength  = "HIGH"
        output_strength = "HIGH"
        type            = "HATE"
      },
      {
        input_strength  = "HIGH"
        output_strength = "HIGH"
        type            = "INSULTS"
      },
      {
        input_strength  = "HIGH"
        output_strength = "HIGH"
        type            = "MISCONDUCT"
      },
      {
        input_strength  = "NONE"
        output_strength = "NONE"
        type            = "PROMPT_ATTACK"
      }
    ]
  }

  # block / mask potential PII information
  sensitive_information_policy_config = {
    pii_entities_config = [
      {
        action = "BLOCK"
        type   = "DRIVER_ID"
      },
      {
        action = "BLOCK"
        type   = "PASSWORD"
      },
      {
        action = "ANONYMIZE"
        type   = "EMAIL"
      },
      {
        action = "ANONYMIZE"
        type   = "USERNAME"
      },
      {
        action = "BLOCK"
        type   = "AWS_ACCESS_KEY"
      },
      {
        action = "BLOCK"
        type   = "AWS_SECRET_KEY"
      },
    ]
  }

  # block select word / profanity
  word_policy_config = {
    managed_word_lists_config = [{
      type = "PROFANITY"
    }]
  }

  tags = [for k, v in local.combined_tags :
    {
      key : k,
      value : v
    }
  ]

}

resource "awscc_bedrock_guardrail_version" "runtask_fulfillment" {
  guardrail_identifier = awscc_bedrock_guardrail.runtask_fulfillment.guardrail_id
  description          = "Initial version"
}
