#!/usr/bin/env python3

"""Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)

github.com/sqlxpert/z-container-api-kafka-aws-terraform
GPLv3, Copyright Paul Marcelin
"""

from time import time as time_time
from connexion import AsyncApp as connexion_AsyncApp
from connexion import options as connexion_options


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
    return (
        {
            "timestamp": int(time_time()),  # Truncate fractional second
            "message": f"Hello {name}",
        },
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
