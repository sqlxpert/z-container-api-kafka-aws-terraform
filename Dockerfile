# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

FROM --platform=linux/arm64 amazonlinux:2023.8.20250818.0@sha256:f5077958231a41decbd60c59c48cdb30519b77fdd326e829893470e3a8aa2e55

SHELL ["/usr/bin/bash", "-c"]

RUN \
  dnf --assumeyes install \
    shadow-utils \
    python3.12 \
  && dnf clean all
# shadow-utils provides useradd

RUN useradd --shell /usr/bin/bash --home /hello_api --user-group --uid 1011 hello_api
USER hello_api
WORKDIR /hello_api

ENV VIRTUAL_ENV="/hello_api/python_venv"
RUN python3.12 -m venv "${VIRTUAL_ENV}"
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

COPY requirements.txt .
RUN \
  pip install --upgrade pip \
  && pip install --requirement requirements.txt \
  && pip cache purge

COPY hello_api.openapi.yaml hello_api.py .

EXPOSE 8000/tcp
CMD gunicorn \
  --log-level 'error' \
  --error-logfile '-' \
  --access-logfile '-' \
  --bind '0.0.0.0:8000' \
  --worker-class 'uvicorn.workers.UvicornWorker' \
  'hello_api:hello_api_app'