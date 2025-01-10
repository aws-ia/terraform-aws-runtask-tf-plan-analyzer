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

HCP_TF_ORG = os.environ.get("HCP_TF_ORG", False)
WORKSPACE_PREFIX = os.environ.get("WORKSPACE_PREFIX", False)
RUNTASK_STAGES = os.environ.get("RUNTASK_STAGES", False)
EVENT_RULE_DETAIL_TYPE = os.environ.get("EVENT_RULE_DETAIL_TYPE", "tfplan-analyzer") # assume there could be multiple deployment of this module, this will ensure each rule are unique

logger = logging.getLogger()
log_level = os.environ.get("log_level", logging.INFO)

logger.setLevel(log_level)
logger.info("Log level set to %s" % logger.getEffectiveLevel())


def lambda_handler(event, _):
    logger.debug(json.dumps(event))
    try:
        VERIFY = True
        if event["payload"]["detail-type"] == EVENT_RULE_DETAIL_TYPE:
            if (
                HCP_TF_ORG
                and event["payload"]["detail"]["organization_name"] != HCP_TF_ORG
            ):
                logger.error(
                    "HCP Terraform Org verification failed : {}".format(
                        event["payload"]["detail"]["organization_name"]
                    )
                )
                VERIFY = False
            if WORKSPACE_PREFIX and not (
                str(event["payload"]["detail"]["workspace_name"]).startswith(
                    WORKSPACE_PREFIX
                )
            ):
                logger.error(
                    "HCP Terraform workspace prefix verification failed : {}".format(
                        event["payload"]["detail"]["workspace_name"]
                    )
                )
                VERIFY = False
            if RUNTASK_STAGES and not (
                event["payload"]["detail"]["stage"] in RUNTASK_STAGES
            ):
                logger.error(
                    "HCP Terraform run task stage verification failed: {}".format(
                        event["payload"]["detail"]["stage"]
                    )
                )
                VERIFY = False

        if VERIFY:
            return "verified"
        else:
            return "unverified"

    except Exception as e:
        logger.exception("Run Task Request error: {}".format(e))
        raise
