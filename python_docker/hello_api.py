#!/usr/bin/env python3

"""Containerized REST API, Kafka, Lambda consumer, via Terraform+CloudFormation

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
from kafka.sasl.oauth import (
    AbstractTokenProvider as kafka_AbstractTokenProvider,
)
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
from kafka.errors import (  # pylint: disable=ungrouped-imports
    TopicAlreadyExistsError as kafka_TopicAlreadyExistsError,
)
from kafka.admin import (
    KafkaAdminClient as kafka_KafkaAdminClient,
    NewTopic as kafka_NewTopic,
)
from kafka import KafkaProducer as kafka_KafkaProducer


AWS_REGION = os_environ.get(
    "AWS_REGION", os_environ.get("AWS_DEFAULT_REGION", "")
    # Downstream error intended in region is empty!
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


class MSKTokenProvider(kafka_AbstractTokenProvider):  # pylint:disable=too-few-public-methods
    """Generate an OAUTHBEARER token to access AWS MSK using IAM authentication
    """

    def token(self):
        """Get an OAUTHBEARER token to access AWS MSK using IAM permissions
        """
        (token, _) = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token


kafka_token_provider = None  # pylint: disable=invalid-name


def kafka_token_provider_get():
    """Return the Kafka token provider, creating it first if necessary
    """
    global kafka_token_provider  # pylint: disable=global-statement

    if kafka_token_provider is None:
        kafka_token_provider = MSKTokenProvider()

    return kafka_token_provider


kafka_topic_created = False  # pylint: disable=invalid-name


def kafka_topic_create():
    """Idempotently create the designated Kafka topic
    """
    global kafka_topic_created  # pylint: disable=global-statement

    if not kafka_topic_created:
        try:
            kafka_admin_client = kafka_KafkaAdminClient(
                bootstrap_servers=HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP,
                security_protocol="SASL_SSL",
                sasl_mechanism="OAUTHBEARER",
                sasl_oauth_token_provider=kafka_token_provider_get(),
                client_id=KAFKA_CLIENT_ID,

                request_timeout_ms=1000,
                connections_max_idle_ms=30000,
                retry_backoff_ms=100,
                max_in_flight_requests_per_connection=1,
            )
            kafka_admin_client.create_topics(
                new_topics=[kafka_NewTopic(
                    name=HELLO_API_AWS_MSK_CLUSTER_TOPIC,
                    num_partitions=1,
                    replication_factor=1,
                )],
                timeout_ms=1000,
            )
            kafka_topic_created = True
            kafka_admin_client.close()

        except kafka_TopicAlreadyExistsError:
            kafka_topic_created = True

        except Exception as misc_exception:  # pylint: disable=broad-exception-caught
            print(json_dumps(
                {
                    "new_topic": HELLO_API_AWS_MSK_CLUSTER_TOPIC,
                    "exception": str(misc_exception),
                },
                default=str,
            ))


kafka_producer = None  # pylint: disable=invalid-name


def kafka_producer_get():
    """Return a Kafka producer, creating it first if necessary
    """
    global kafka_producer  # pylint: disable=global-statement

    if kafka_producer is None:
        kafka_producer = kafka_KafkaProducer(
            bootstrap_servers=HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP,
            security_protocol="SASL_SSL",
            sasl_mechanism="OAUTHBEARER",
            sasl_oauth_token_provider=kafka_token_provider_get(),
            client_id=KAFKA_CLIENT_ID,

            # Topic auto-creation requires a server-side setting not available
            # in MSK Serverless, hence kafka_topic_create .
            allow_auto_create_topics=False,

            # As suggested in
            # https://kafka-python.readthedocs.io/en/master/usage.html#kafkaproducer
            # with my addition of the string default in anticipation of future
            # values, such as Python dates, that can't be serialized to JSON
            value_serializer=lambda message: json_dumps(
                message,
                default=str
            ).encode("utf-8"),

            # Send more or less immediately (adjust for larger volume of data)
            batch_size=0,
            request_timeout_ms=500,
            linger_ms=0,
            delivery_timeout_ms=1000,
            retries=1,
            retry_backoff_ms=100,
            max_in_flight_requests_per_connection=1,
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
            "message": "Hello, World!",
        },
        200,
    )


def current_time_get(name):
    """ Return epoch time, hello message with reflected string, in JSON object
    """
    message = {
        "timestamp": int(time_time()),  # Truncate fractional second
        "message": f"Hello, {name}!",
    }
    if ENABLE_KAFKA:

        try:
            kafka_topic_create()
            future_kafka_record_metadata = kafka_producer_get().send(
                HELLO_API_AWS_MSK_CLUSTER_TOPIC,
                message
            )
            kafka_record_metadata = future_kafka_record_metadata.get(
                timeout=2
                # seconds even tough KafkaProducer uses milliseconds,
                # as in request_timeout_ms (!)
            )
            print(json_dumps(
                {
                    "sent_message": message,
                    "kafka_topic": kafka_record_metadata.topic,
                    "kafka_partition": kafka_record_metadata.partition,
                    "kafka_offset": kafka_record_metadata.offset,
                },
                default=str,
            ))

        except Exception as misc_exception:  # pylint: disable=broad-exception-caught
            print(json_dumps(
                {
                    "send_message": message,
                    "exception": str(misc_exception),
                },
                default=str,
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
