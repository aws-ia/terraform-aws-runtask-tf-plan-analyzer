import json
import os
import re

import boto3
import botocore

from runtask_utils import generate_runtask_result
from tools.get_ami_releases import GetECSAmisReleases
from utils import logger, stream_messages, tool_config
import xml.etree.ElementTree as ET

# Initialize model_id and region
model_id = os.environ.get("BEDROCK_LLM_MODEL")
guardrail_id = os.environ.get("BEDROCK_GUARDRAIL_ID", None)
guardrail_version = os.environ.get("BEDROCK_GUARDRAIL_VERSION", None)

# Config to avoid timeouts when using long prompts
config = botocore.config.Config(
    read_timeout=1800, connect_timeout=1800, retries={"max_attempts": 0}
)

session = boto3.Session()
bedrock_client = session.client(
    service_name="bedrock-runtime", config=config
)

# Input is the terraform plan JSON
def eval(tf_plan_json):

    #####################################################################
    ##### First, do generic evaluation of the Terraform plan output #####
    #####################################################################

    logger.info("##### Evaluating Terraform plan output #####")
    prompt = """
    You must respond with ONLY a JSON object. Do not include any explanatory text, conversation, or markdown formatting.

    Analyze the terraform plan and return this exact JSON structure:
    {"thinking": "brief analysis", "resources": "list of resources being created, modified, or deleted"}

    Terraform plan:
    """

    prompt += f"""
    {tf_plan_json["resource_changes"]}
    """

    messages = [
        {
            "role": "user",
            "content": [
                {
                    "text": prompt,
                }
            ],
        }
    ]

    system_text = "You are a JSON-only response system. Return only valid JSON with no additional text or formatting."

    stop_reason, analysis_response = stream_messages(
        bedrock_client, model_id, messages, system_text
    )

    logger.debug("Analysis response: {}".format(analysis_response))

    try:
        analysis_response_text = clean_response(analysis_response["content"][0]["text"])["resources"]
    except Exception as e:
        logger.error(f"Error parsing analysis response: {e}")
        analysis_response_text = "Error: Could not parse Terraform plan analysis"

    logger.debug("Analysis response Text: {}".format(analysis_response_text))

    #####################################################################
    ######## Secondly, evaluate AMIs per analysis                ########
    #####################################################################
    logger.info("##### Evaluating AMI information #####")
    prompt = f"""
    For any Amazon Machine Image (AMI) changes in this analysis, use the get_ami_releases function to compare old and new AMI details including kernel, docker, and ECS agent versions.

    Analysis: {analysis_response_text}
    """

    messages = [{"role": "user", "content": [{"text": prompt}]}]

    stop_reason, response = stream_messages(
        bedrock_client=bedrock_client,
        model_id=model_id,
        messages=messages,
        system_text="Provide direct, technical analysis of AMI changes without conversational language.",
        tool_config=tool_config,
    )

    # Add response to message history
    messages.append(response)

    # Check if there is an invoke function request from Claude
    while stop_reason == "tool_use":
        for content in response["content"]:
            if "toolUse" in content:
                tool = content["toolUse"]

                if tool["name"] == "GetECSAmisReleases":

                    release_details = GetECSAmisReleases().execute(
                        tool["input"]["image_ids"]
                    )
                    release_details_info = release_details if release_details else "No release notes were found the ami."

                    tool_result = {
                        "toolUseId": tool["toolUseId"],
                        "content": [{"json": {"release_detail": release_details_info}}],
                    }

                    tool_result_message = {
                        "role": "user",
                        "content": [{"toolResult": tool_result}],
                    }
                    # Add the result info to message array
                    messages.append(tool_result_message)

        # Send the messages, including the tool result, to the model.
        stop_reason, response = stream_messages(
            bedrock_client=bedrock_client,
            model_id=model_id,
            messages=messages,
            system_text="Provide direct, technical analysis of AMI changes without conversational language.",
            tool_config=tool_config,
        )

        # Add response to message history
        messages.append(response)

    # Extract the actual response text from Bedrock
    if response and "content" in response and len(response["content"]) > 0:
        result = response["content"][0]["text"]
        logger.debug("AMI analysis response: {}".format(result))
    else:
        result = "Error: No AMI analysis response received from Bedrock"
        logger.error("No AMI analysis content received from Bedrock")

    #####################################################################
    ######### Third, generate short summary                     #########
    #####################################################################

    logger.info("##### Generating short summary #####")
    prompt = f"""
    Provide a concise summary of these Terraform changes. Focus on what resources are being created, modified, or deleted:

    {tf_plan_json["resource_changes"]}
    """
    message_desc = [{"role": "user", "content": [{"text": prompt}]}]
    stop_reason, response = stream_messages(
        bedrock_client=bedrock_client,
        model_id=model_id,
        messages=message_desc,
        system_text="Provide a direct, technical summary without conversational language.",
        tool_config=None,
    )

    # Extract the actual response text from Bedrock
    if response and "content" in response and len(response["content"]) > 0:
        description = response["content"][0]["text"]
        logger.debug("Full Bedrock response: {}".format(description))
    else:
        description = "Error: No response received from Bedrock"
        logger.error("No response content received from Bedrock")

    logger.info("##### Report #####")
    logger.info("Analysis : {}".format(analysis_response_text))
    logger.info("AMI summary: {}".format(result))
    logger.info("Terraform plan summary: {}".format(description))

    results = []

    guardrail_status, guardrail_response = guardrail_inspection(str(description))
    if guardrail_status:
        results.append(generate_runtask_result(outcome_id="Plan-Summary", description="Summary of Terraform plan", result=description[:9000])) # body max limit of 10,000 chars
    else:
        results.append(generate_runtask_result(outcome_id="Plan-Summary", description="Summary of Terraform plan", result="Output omitted due to : {}".format(guardrail_response)))
        description = "Bedrock guardrail triggered : {}".format(guardrail_response)

    guardrail_status, guardrail_response = guardrail_inspection(str(result))
    if guardrail_status:
        results.append(generate_runtask_result(outcome_id="AMI-Summary", description="Summary of AMI changes", result=result[:700]))
    else:
        results.append(generate_runtask_result(outcome_id="AMI-Summary", description="Summary of AMI changes", result="Output omitted due to : {}".format(guardrail_response)))

    runtask_high_level ="Terraform plan analyzer using Amazon Bedrock, expand the findings below to learn more. Click `view more details` to get the detailed logs"
    return runtask_high_level, results

def guardrail_inspection(input_text, input_mode = 'OUTPUT'):

    #####################################################################
    ##### Inspect input / output against Bedrock Guardrail          #####
    #####################################################################

    if guardrail_id and guardrail_version:
        logger.info("##### Scanning Terraform plan output with Amazon Bedrock Guardrail #####")

        response = bedrock_client.apply_guardrail(
            guardrailIdentifier=guardrail_id,
            guardrailVersion=guardrail_version,
            source=input_mode,
            content=[
                {
                    'text': {
                        'text': input_text,
                    }
                },
            ]
        )

        logger.debug("Guardrail inspection result : {}".format(json.dumps(response)))

        if response["action"] in ["GUARDRAIL_INTERVENED"]:
            logger.info("Guardrail action : {}".format(response["action"]))
            logger.info("Guardrail output : {}".format(response["outputs"]))
            logger.debug("Guardrail assessments : {}".format(response["assessments"]))
            return False, response["outputs"][0]["text"]

        elif response["action"] in ["NONE"]:
            logger.info("No Guardrail action required")
            return True, "No Guardrail action required"

    else:
        return True, "Guardrail inspection skipped"

def clean_response(json_str):
    try:
        # First try to parse as-is
        return json.loads(json_str)
    except json.JSONDecodeError:
        try:
            # Remove any tags in the format <tag> or </tag>
            cleaned_str = re.sub(r'<\/?[\w\s]+>', '', json_str)

            # Find JSON content between braces
            start_brace = cleaned_str.find('{')
            last_brace = cleaned_str.rfind('}')

            if start_brace != -1 and last_brace != -1 and last_brace > start_brace:
                json_content = cleaned_str[start_brace:last_brace + 1]
                return json.loads(json_content)
            else:
                logger.error(f"No valid JSON braces found in response: {json_str}")
                return {"resources": "Error: No valid JSON structure found"}

        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error after cleaning: {e}, Original string: {json_str}")
            return {"resources": "Error: Could not parse response as JSON"}
    except Exception as e:
        logger.error(f"Unexpected error in clean_response: {e}, Original string: {json_str}")
        return {"resources": "Error: Unexpected parsing error"}
