# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

FROM amazonlinux:2023.8.20250818.0@sha256:f5077958231a41decbd60c59c48cdb30519b77fdd326e829893470e3a8aa2e55

LABEL org.opencontainers.image.base.name="docker.io/library/amazonlinux:2023.8.20250818.0"
LABEL org.opencontainers.image.base.digest="sha256:f5077958231a41decbd60c59c48cdb30519b77fdd326e829893470e3a8aa2e55"

LABEL org.opencontainers.image.documentation="https://github.com/sqlxpert/z-container-api-kafka-aws-terraform"

LABEL org.opencontainers.image.title="Hello world API"
LABEL org.opencontainers.image.description="Uses Python 3.12, OpenAPI 3.0, Connexion, Uvicorn workers, Gunicorn"
LABEL org.opencontainers.image.authors="Paul Marcelin"
LABEL org.opencontainers.image.vendor="Paul Marcelin"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"
LABEL org.opencontainers.image.source="https://github.com/sqlxpert/z-container-api-kafka-aws-terraform/blob/main/Dockerfile"

SHELL ["/usr/bin/bash", "-c"]

RUN \
  --mount=type=cache,target=/var/cache/dnf,sharing=locked \
  --mount=type=cache,target=/var/lib/dnf,sharing=locked \
  dnf install \
    --assumeyes \
    --nodocs \
    python3.12-3.12.11-2.amzn2023.0.2 \
    shadow-utils-2:4.9-12.amzn2023.0.4 \
  && useradd --shell /usr/bin/bash --home /hello_api --user-group --uid 1011 hello_api \
  && dnf remove \
    --assumeyes \
    --setopt=clean_requirements_on_remove=True \
    shadow-utils-2:4.9-12.amzn2023.0.4
# shadow-utils provides useradd

USER hello_api
WORKDIR /hello_api

ENV VIRTUAL_ENV="/hello_api/python_venv"
RUN python3.12 -m venv "${VIRTUAL_ENV}"
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

###############################################################################
# Local file references ( --mount=type=bind,source= , COPY , ADD )
#
# Also add files to .dockerignore ; mine ignores files not explicitly listed.

RUN \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  --mount=type=cache,target=/root/.cache/pip \
  pip install --upgrade pip==25.2 \
  && pip install --requirement /tmp/requirements.txt

COPY \
  hello_api.openapi.yaml \
  hello_api.py \
  ./

###############################################################################

EXPOSE 8000/tcp
CMD ["gunicorn", "--log-level", "error", "--error-logfile", "-", "--access-logfile", "-", "--worker-class", "uvicorn.workers.UvicornWorker", "--worker-tmp-dir", "/dev/shm", "--workers", "2",  "--bind", "0.0.0.0:8000", "hello_api:hello_api_app"]
