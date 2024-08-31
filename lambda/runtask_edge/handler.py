import base64
import hashlib
import json
import logging
import os

logger = logging.getLogger()
log_level = os.environ.get("log_level", logging.INFO)

logger.setLevel(log_level)
logger.info("Log level set to %s" % logger.getEffectiveLevel())


def lambda_handler(event, _):
    logger.info("Incoming event : {}".format(json.dumps(event)))
    request = event['Records'][0]['cf']['request']
    headers = request["headers"]
    headerName = 'x-amz-content-sha256'

    '''
    CloudFront Origin Access Control will not automatically calculate the payload hash.
    this Lambda@Edge will calculate the payload hash and append new header x-amz-content-sha256
    '''
    payload_body = decode_body(request['body']['data'])
    logger.debug("Payload : {}".format(payload_body))
    payload_hash = calculate_payload_hash(payload_body)

    # inject new header
    headers[headerName] = [{'key': headerName, 'value': payload_hash}]

    logger.info("Returning request: %s" % json.dumps(request))
    return request


def decode_body(encoded_body):
    return base64.b64decode(encoded_body).decode('utf-8')


def calculate_payload_hash(payload):
    ## generate sha256 from payload
    return hashlib.sha256(payload.encode('utf-8')).hexdigest()
