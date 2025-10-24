#!/usr/bin/env python3

"""Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)

github.com/sqlxpert/z-container-api-kafka-aws-terraform
GPLv3, Copyright Paul Marcelin

MSK authentication code adapted from:
https://aws.amazon.com/blogs/big-data/amazon-msk-serverless-now-supports-kafka-clients-written-in-all-programming-languages/
"""

from os import environ as os_environ
from time import time as time_time
from json import dumps as json_dumps
from connexion import AsyncApp as connexion_AsyncApp
from connexion import options as connexion_options
from kafka.sasl.oauth import AbstractTokenProvider
from kafka import KafkaProducer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider


AWS_REGION = os_environ.get(
    "AWS_REGION", os_environ.get("AWS_DEFAULT_REGION", "us-west-2")
)
HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP = os_environ.get(
    "HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP", ""
)
ENABLE_KAFKA = bool(HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP)
HELLO_API_AWS_MSK_CLUSTER_TOPIC = os_environ.get(
    "HELLO_API_AWS_MSK_CLUSTER_TOPIC", "events"
)
KAFKA_CLIENT_ID = "hello_api"
# Desired: Containers.DockerId (low priority; requires adding requests module)
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint-v4-response.html


class MSKTokenProvider(AbstractTokenProvider):  # pylint:disable=too-few-public-methods
    """Generate an OAUTHBEARER token to access AWS MSK using IAM authentication
    """

    def token(self):
        """Get an OAUTHBEARER token to access AWS MSK using IAM permissions

        TODO: Check whether configuration is suitable for production, with
        timeouts, retry logic, etc.
        """
        (token, _) = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token


# pylint: disable=invalid-name
kafka_token_provider = None
kafka_producer = None
# pylint: enable=invalid-name


def kafka_producer_get():
    """Return a Kafka producer, creating it first if necessary
    """
    # pylint: disable=global-statement
    global kafka_token_provider
    global kafka_producer
    # pylint: enable=global-statement

    if kafka_token_provider is None:
        kafka_token_provider = MSKTokenProvider()

    if kafka_producer is None:
        kafka_producer = KafkaProducer(
            bootstrap_servers=HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP,
            security_protocol="SASL_SSL",
            sasl_mechanism="OAUTHBEARER",
            sasl_oauth_token_provider=kafka_token_provider,

            client_id=KAFKA_CLIENT_ID,

            # Avoids the need to give Terraform (!) permission to authenticate
            # to Kafka, and then:
            # https://aws.amazon.com/blogs/big-data/automate-topic-provisioning-and-configuration-using-terraform-with-amazon-msk
            # https://registry.terraform.io/providers/Mongey/kafka/latest
            # https://github.com/Mongey/terraform-provider-kafka
            allow_auto_create_topics=True,

            # As suggested in
            # https://kafka-python.readthedocs.io/en/master/usage.html#kafkaproducer
            # with my addition of the string default in anticipation of future
            # values, such as Python dates, that can't be serialized to JSON
            value_serializer=lambda message: json_dumps(
                message,
                default=str
            ).encode(
                "ascii"
            ),

            batch_size=0,  # Send immediately, for this demonstration
            request_timeout_ms=1000,
            retries=1,
            retry_backoff_ms=100,
            max_in_flight_requests_per_connection=5,
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

    if ENABLE_KAFKA:

        try:
            pass
            # future_kafka_record_metadata = kafka_producer_get().send(
            #     HELLO_API_AWS_MSK_CLUSTER_TOPIC,
            #     message
            # )
            # kafka_record_metadata = future_kafka_record_metadata.get(
            #     timeout=3
            #     # seconds even tough KafkaProducer uses milliseconds,
            #     # as in request_timeout_ms (!)
            # )
            # print(json_dumps(
            #     {
            #         "original_message": message,
            #         "kafka_partition": kafka_record_metadata.partition,
            #         "kafka_offset": kafka_record_metadata.offset,
            #     },
            #     default=str
            # ))

        except Exception as misc_exception:  # pylint: disable=broad-exception-caught
            print(json_dumps(
                {
                    "original_message": message,
                    "exception": str(misc_exception),
                },
                default=str
            ))

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
