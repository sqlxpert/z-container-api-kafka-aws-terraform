#!/usr/bin/env python3
"""Containerized REST API, Kafka, Lambda consumer, via Terraform+CloudFormation

github.com/sqlxpert/z-container-api-kafka-aws-terraform
GPLv3, Copyright Paul Marcelin
"""

from logging import getLogger as logging_getLogger, INFO, WARNING, ERROR
from json import dumps as json_dumps, loads as json_loads
from base64 import b64decode as base64_b64decode

logger = logging_getLogger()
# Skip "credentials in environment" INFO message, unavoidable in AWS Lambda:
logging_getLogger("botocore").setLevel(WARNING)


def log(entry_type, entry_value, log_level):
    """Emit a JSON-format log entry
    """
    entry_value_out = json_loads(json_dumps(entry_value, default=str))
    # Avoids "Object of type datetime is not JSON serializable" in
    # https://github.com/aws/aws-lambda-python-runtime-interface-client/blob/9efb462/awslambdaric/lambda_runtime_log_utils.py#L109-L135
    #
    # The JSON encoder in the AWS Lambda Python runtime isn't configured to
    # serialize datatime values in responses returned by AWS's own Python SDK!
    #
    # Alternative considered:
    # https://docs.powertools.aws.dev/lambda/python/latest/core/logger/

    logger.log(
        log_level, "", extra={"type": entry_type, "value": entry_value_out}
    )


def lambda_handler(lambda_event, context):  # pylint: disable=unused-argument
    """Log MSK messages
    """
    log("LAMBDA_EVENT", lambda_event, INFO)

    # topic_partition (form: "topic-partition") is for future use
    # pylint:disable=unused-variable
    for topic_partition, records in lambda_event.get("records", []).items():
        # pylint:enable=unused-variable

        for record in records:

            result = None
            log_level = INFO

            try:
                result = json_loads(base64_b64decode(
                    record.get("value", "")
                ).decode("utf-8"))
            except Exception as misc_exception:  # pylint: disable=broad-exception-caught
                result = misc_exception
                log_level = ERROR

            log("RECORD", record, log_level)
            log(
                "EXCEPTION" if isinstance(result, Exception) else "MESSAGE",
                result,
                log_level
            )
