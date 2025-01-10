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

import json
import logging
import os
import re
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

HCP_TF_HOST_NAME = os.environ.get("HCP_TF_HOST_NAME", "app.terraform.io")

logger = logging.getLogger()
log_level = os.environ.get("log_level", logging.INFO)

logger.setLevel(log_level)
logger.info("Log level set to %s" % logger.getEffectiveLevel())


def lambda_handler(event, _):
    logger.debug(json.dumps(event))
    try:
        # trim empty url from the payload
        if "fulfillment" in event["payload"]["result"] and event["payload"]["result"]["fulfillment"]["url"] == False:
            event["payload"]["result"]["fulfillment"].pop("url")

        if (
            event["payload"]["result"]["request"]["status"] == "unverified"
        ):  # unverified runtask execution
            payload = {
                "data": {
                    "attributes": {
                        "status": "failed",
                        "message": "Verification failed, check HCP Terraform org, workspace prefix or run task stage",
                    },
                    "type": "task-results",
                }
            }
        elif (
            event["payload"]["result"]["stage"]["status"] == "not implemented"
        ):  # unimplemented runtask stage
            payload = {
                "data": {
                    "attributes": {
                        "status": "failed",
                        "message": "Runtask is not configured to run on this stage {}".format(
                            event["payload"]["detail"]["stage"]
                        ),
                    },
                    "type": "task-results",
                }
            }
        elif event["payload"]["result"]["fulfillment"]["status"] in [
            "passed",
            "failed",
        ]:  # return from fulfillment regardless of status
            payload = {
                "data": {
                    "attributes": event["payload"]["result"]["fulfillment"],
                    "type": "task-results",
                    "relationships": {
                        "outcomes": {
                            "data": event["payload"]["result"]["fulfillment"][
                                "results"
                            ],
                        }
                    },
                }
            }

        logger.info("Payload : {}".format(json.dumps(payload)))

        # Send runtask callback response to HCP Terraform
        endpoint = event["payload"]["detail"]["task_result_callback_url"]
        access_token = event["payload"]["detail"]["access_token"]
        headers = __build_standard_headers(access_token)
        response = __patch(
            endpoint, headers, bytes(json.dumps(payload), encoding="utf-8")
        )
        logger.debug("HCP Terraform response: {}".format(response))
        return "completed"

    except Exception as e:
        logger.exception("HCP Terraform run task Callback error: {}".format(e))
        raise


def __build_standard_headers(api_token):
    return {
        "Authorization": "Bearer {}".format(api_token),
        "Content-type": "application/vnd.api+json",
    }


def __patch(endpoint, headers, payload):
    request = Request(endpoint, headers=headers or {}, data=payload, method="PATCH")
    try:
        if validate_endpoint(endpoint):
            with urlopen(request, timeout=10) as response:  # nosec URL validation
                return response.read(), response
        else:
            raise URLError(
                f"Invalid endpoint URL, expected host is: {HCP_TF_HOST_NAME}"
            )
    except HTTPError as error:
        logger.error(error.status, error.reason)
    except URLError as error:
        logger.error(error.reason)
    except TimeoutError:
        logger.error("Request timed out")


def validate_endpoint(endpoint):  # validate that the endpoint hostname is valid
    pattern = "^https:\/\/" + str(HCP_TF_HOST_NAME).replace(".", "\.") + "\/" + ".*"
    result = re.match(pattern, endpoint)
    return result
