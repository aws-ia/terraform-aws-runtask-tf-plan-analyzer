import json
import logging
import os
import re
import time
from urllib.error import HTTPError, URLError
from urllib.request import urlopen, Request

import requests

logging.basicConfig(format="%(levelname)s: %(message)s")
logger = logging.getLogger()

hcp_tf_host_name = os.environ.get("HCP_TF_HOST_NAME", "app.terraform.io")


def download_config(configuration_version_download_url, access_token):
    headers = {
        "Content-Type": "application/vnd.api+json",
        "Authorization": "Bearer " + access_token,
    }
    response = requests.get(configuration_version_download_url, headers=headers, timeout=30)

    config_file = os.path.join(os.getcwd(), "pre_plan", "config.tar.gz")
    os.makedirs(os.path.dirname(config_file), exist_ok=True)
    with open(config_file, "wb") as file:
        file.write(response.content)

    return config_file


def get_plan(url, access_token) -> (str, str):
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-type": "application/vnd.api+json",
    }

    request = Request(url, headers=headers, method="GET")
    try:
        if validate_endpoint(url):
            with urlopen(request, timeout=10) as response:
                response_raw = response
                response_read = response.read()
                json_response = json.loads(response_read.decode("utf-8"))

            logger.debug(f"Headers: {response_raw.headers}")
            logger.debug(f"JSON Response: {json.dumps(json_response, indent=4)}")
            return json_response, None
        else:
            return (
                None,
                f"Error: Invalid endpoint URL, expected host is {hcp_tf_host_name}",
            )
    except HTTPError as error:
        logger.error(str(f"HTTP error: status {error.status} - {error.reason}"))
        return None, f"HTTP Error: {str(error)}"
    except URLError as error:
        logger.error(str(f"URL error: {error.reason}"))
        return None, f"URL Error: {str(error)}"
    except TimeoutError as error:
        logger.error(f"Timeout error: {str(error)}")
        return None, f"Timeout Error: {str(error)}"
    except Exception as error:
        logger.error(str(error))
        return None, f"Exception: {str(error)}"


def validate_endpoint(endpoint):
    # validate that the endpoint hostname is valid
    pattern = r"^https://" + str(hcp_tf_host_name).replace(".", r"\.") + r"/.*"
    result = re.match(pattern, endpoint)
    return result


def generate_runtask_result(outcome_id, description, result):
    result_json = json.dumps(
        {
            "type": "task-result-outcomes",
            "attributes": {
                "outcome-id": outcome_id,
                "description": description,
                "body": f"{result}",
                "tags": {
                    "status": [{"label": "Passed", "level": "info"}],
                    "severity": [
                        {
                            "label": "Info",
                            "level": "info",
                        }
                    ],
                },
            },
        },
        separators=(",", ":"),
    )
    return json.loads(result_json)


def convert_to_markdown(result):
    result = result.replace("\n", "<br>")
    result = result.replace("##", "<br>##")
    result = result.replace("*", "<br>*")
    result = result.replace("<br><br>", "<br>")
    return result


def log_helper(cwl_client, log_group_name, log_stream_name,
               log_message):  # helper function to write RunTask results to dedicated cloudwatch log group
    if log_group_name:  # true if CW log group name is specified
        global SEQUENCE_TOKEN
        try:
            SEQUENCE_TOKEN = log_writer(cwl_client, log_group_name, log_stream_name, log_message, SEQUENCE_TOKEN)[
                "nextSequenceToken"]
        except:
            cwl_client.create_log_stream(logGroupName=log_group_name, logStreamName=log_stream_name)
            SEQUENCE_TOKEN = log_writer(cwl_client, log_group_name, log_stream_name, log_message)["nextSequenceToken"]


def log_writer(cwl_client, log_group_name, log_stream_name, log_message,
               sequence_token=False):  # writer to CloudWatch log stream based on sequence token
    if sequence_token:  # if token exists, append to the previous token stream
        response = cwl_client.put_log_events(
            logGroupName=log_group_name,
            logStreamName=log_stream_name,
            logEvents=[{
                'timestamp': int(round(time.time() * 1000)),
                'message': time.strftime('%Y-%m-%d %H:%M:%S') + ": " + log_message
            }],
            sequenceToken=sequence_token
        )
    else:  # new log stream, no token exist
        response = cwl_client.put_log_events(
            logGroupName=log_group_name,
            logStreamName=log_stream_name,
            logEvents=[{
                'timestamp': int(round(time.time() * 1000)),
                'message': time.strftime('%Y-%m-%d %H:%M:%S') + ": " + log_message
            }]
        )
    return response
