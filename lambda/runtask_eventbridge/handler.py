"""
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""

"""HashiCorp HCP Terraform run task event handler implementation"""

import os
import hmac
import json
import base64
import hashlib
import logging
import urllib.parse
import boto3
import botocore
import botocore.session

from cgi import parse_header
from aws_secretsmanager_caching import SecretCache, SecretCacheConfig

client = botocore.session.get_session().create_client("secretsmanager")
cache_config = SecretCacheConfig()
cache = SecretCache(config=cache_config, client=client)

hcp_tf_hmac_secret_arn = os.environ.get("HCP_TF_HMAC_SECRET_ARN")
hcp_tf_use_waf = os.environ.get("HCP_TF_USE_WAF")
hcp_tf_cf_secret_arn = os.environ.get("HCP_TF_CF_SECRET_ARN")
hcp_tf_cf_signature = os.environ.get("HCP_TF_CF_SIGNATURE")

logger = logging.getLogger()
log_level = os.environ.get("log_level", logging.INFO)

logger.setLevel(log_level)
logger.info("Log level set to %s" % logger.getEffectiveLevel())

event_bus_name = os.environ.get("EVENT_BUS_NAME", "default")
event_bridge_client = boto3.client("events")


def _add_header(request, **kwargs):
    userAgentHeader = request.headers["User-Agent"] + " fURLWebhook/1.0 (HashiCorp)"
    del request.headers["User-Agent"]
    request.headers["User-Agent"] = userAgentHeader


event_system = event_bridge_client.meta.events
event_system.register_first("before-sign.events.PutEvents", _add_header)


class PutEventError(Exception):
    """Raised when Put Events Failed"""

    pass


def lambda_handler(event, _context):
    """Terraform run task function"""
    logger.debug(json.dumps(event))

    headers = event.get("headers")
    # Input validation
    try:
        json_payload = get_json_payload(event=event)
    except ValueError as err:
        print_error(f"400 Bad Request - {err}", headers)
        return {"statusCode": 400, "body": str(err)}
    except BaseException as err:  # Unexpected Error
        print_error(
            "500 Internal Server Error\n" + f"Unexpected error: {err}, {type(err)}",
            headers,
        )
        return {"statusCode": 500, "body": "Internal Server Error"}

    detail_type = "hcp-tf-runtask"
    try:
        if hcp_tf_use_waf == "True" and not contains_valid_cloudfront_signature(
            event=event
        ):
            print_error("401 Unauthorized - Invalid CloudFront Signature", headers)
            return {"statusCode": 401, "body": "Invalid CloudFront Signature"}

        if not contains_valid_signature(event=event):
            print_error("401 Unauthorized - Invalid Payload Signature", headers)
            return {"statusCode": 401, "body": "Invalid Payload Signature"}

        response = forward_event(json_payload, detail_type)

        if response["FailedEntryCount"] > 0:
            print_error(
                "500 FailedEntry Error - The event was not successfully forwarded to Amazon EventBridge\n"
                + str(response["Entries"][0]),
                headers,
            )
            return {
                "statusCode": 500,
                "body": "FailedEntry Error - The entry could not be succesfully forwarded to Amazon EventBridge",
            }

        return {"statusCode": 200, "body": "Message forwarded to Amazon EventBridge"}

    except PutEventError as err:
        print_error(f"500 Put Events Error - {err}", headers)
        return {
            "statusCode": 500,
            "body": "Internal Server Error - The request was rejected by Amazon EventBridge API",
        }

    except BaseException as err:  # Unexpected Error
        print_error(
            "500 Internal Server Error\n" + f"Unexpected error: {err}, {type(err)}",
            headers,
        )
        return {"statusCode": 500, "body": "Internal Server Error"}


def normalize_payload(raw_payload, is_base64_encoded):
    """Decode payload if needed"""
    if raw_payload is None:
        raise ValueError("Missing event body")
    if is_base64_encoded:
        return base64.b64decode(raw_payload).decode("utf-8")
    return raw_payload


def contains_valid_cloudfront_signature(
    event,
):  # Check for the special header value from CloudFront
    try:
        secret = cache.get_secret_string(hcp_tf_cf_secret_arn)
        payload_signature = event["headers"]["x-cf-sig"]
        if secret == payload_signature:
            return True
        else:
            return False
    except:
        logger.error("Unable to validate CloudFront custom header signature value")
        return False


def contains_valid_signature(event):
    """Check for the payload signature
    HashiCorp Terraform run task documention: https://developer.hashicorp.com/terraform/cloud-docs/integrations/run-tasks#securing-your-run-task
    """
    secret = cache.get_secret_string(hcp_tf_hmac_secret_arn)
    payload_bytes = get_payload_bytes(
        raw_payload=event["body"], is_base64_encoded=event["isBase64Encoded"]
    )
    computed_signature = compute_signature(payload_bytes=payload_bytes, secret=secret)

    return hmac.compare_digest(
        event["headers"].get("x-tfc-task-signature", ""), computed_signature
    )


def get_payload_bytes(raw_payload, is_base64_encoded):
    """Get payload bytes to feed hash function"""
    if is_base64_encoded:
        return base64.b64decode(raw_payload)
    else:
        return raw_payload.encode()


def compute_signature(payload_bytes, secret):
    """Compute HMAC-SHA512"""
    m = hmac.new(key=secret.encode(), msg=payload_bytes, digestmod=hashlib.sha512)
    return m.hexdigest()


def get_json_payload(event):
    """Get JSON string from payload"""
    content_type = get_content_type(event.get("headers", {}))
    if not (
        content_type == "application/json"
        or content_type == "application/x-www-form-urlencoded"
    ):
        raise ValueError("Unsupported content-type")

    payload = normalize_payload(
        raw_payload=event.get("body"), is_base64_encoded=event["isBase64Encoded"]
    )

    if content_type == "application/x-www-form-urlencoded":
        parsed_qs = urllib.parse.parse_qs(payload)
        if "payload" not in parsed_qs or len(parsed_qs["payload"]) != 1:
            raise ValueError("Invalid urlencoded payload")

        payload = parsed_qs["payload"][0]

    try:
        json.loads(payload)

    except ValueError as err:
        raise ValueError("Invalid JSON payload") from err

    return payload


def forward_event(payload, detail_type):
    """Forward event to EventBridge"""
    try:
        return event_bridge_client.put_events(
            Entries=[
                {
                    "Source": "app.terraform.io",
                    "DetailType": detail_type,
                    "Detail": payload,
                    "EventBusName": event_bus_name,
                },
            ]
        )
    except BaseException as err:
        raise PutEventError("Put Events Failed")


def get_content_type(headers):
    """Helper function to parse content-type from the header"""
    raw_content_type = headers.get("content-type")

    if raw_content_type is None:
        return None
    content_type, _ = parse_header(raw_content_type)
    return content_type


def print_error(message, headers):
    """Helper function to print errors"""
    logger.error(f"ERROR: {message}\nHeaders: {str(headers)}")
