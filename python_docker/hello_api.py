#!/usr/bin/env python3

"""Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)

github.com/sqlxpert/z-container-api-kafka-aws-terraform
GPLv3, Copyright Paul Marcelin

MSK authentication code adapted from:
https://aws.amazon.com/blogs/big-data/amazon-msk-serverless-now-supports-kafka-clients-written-in-all-programming-languages/
"""

from os import environ as os_environ
from time import time as time_time
from connexion import AsyncApp as connexion_AsyncApp
from connexion import options as connexion_options
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
from kafka import KafkaProducer


AWS_REGION = os_environ.get("AWS_REGION", "us-west-2")
HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP = os_environ.get(
    "HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP", ""
)


class MSKTokenProvider():  # pylint:disable=too-few-public-methods
    """Generate an OAUTHBEARER token to access AWS MSK using IAM authentication
    """

    def token(self):  # pylint:disable=no-self-use
        """Get an OAUTHBEARER token to access AWS MSK using IAM authentication

        TODO: Check whether configuration is suitable for production, with
        timeouts, retry logic, etc.
        """
        (token, _) = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token


tp = MSKTokenProvider()
kafka_producer = None  # pylint: disable=invalid-name


def kafka_producer_get():
    """Return a Kafka producer, creating it first if necessary
    """
    global kafka_producer  # pylint: disable=global-statement

    if kafka_producer is None:
        # TODO: Check whether configuration is suitable for production, with
        # timeouts, retry logic, etc.
        kafka_producer = KafkaProducer(
            bootstrap_servers=HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP,
            security_protocol="SASL_SSL",
            sasl_mechanism="OAUTHBEARER",
            sasl_oauth_token_provider=tp,
            client_id="my.kafka.client.unique.id",
        )

    return kafka_producer


def healthcheck_get():
    """Return HTTP status 200
    """
    return (
        None,
        200,
    )


def hello_get():
    """Return invariable hello message in a JSON object
    """
    return (
        {
            "message": "Hello World!",
        },
        200,
    )


def current_time_get(name):
    """ Return epoch time, hello message with reflected string, in JSON object
    """

    message = {
        "timestamp": int(time_time()),  # Truncate fractional second
        "message": f"Hello {name}",
    }

    try:
        kafka_producer_get()
    except Exception as misc_exception:  # pylint: disable=broad-exception-caught
        print(str(misc_exception))

    return (
        message,
        200,
    )


def chrome_devtools_json_get():
    """Return HTTP status 200
    """
    return (
        None,
        200,
    )


hello_api_app = connexion_AsyncApp(
    __name__,

    # Secure:
    strict_validation=True,
    swagger_ui_options=connexion_options.SwaggerUIOptions(
        serve_spec=False,
        swagger_ui=False,
    ),

    # Intercept bugs:
    validate_responses=True,
)
hello_api_app.add_api("hello_api.openapi.yaml")
