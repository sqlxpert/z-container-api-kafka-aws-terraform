# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

FROM amazonlinux:2023.8.20250818.0@sha256:f5077958231a41decbd60c59c48cdb30519b77fdd326e829893470e3a8aa2e55

SHELL ["/usr/bin/bash", "-c"]

RUN \
  --mount=type=cache,target=/var/cache/dnf,sharing=locked \
  --mount=type=cache,target=/var/lib/dnf,sharing=locked \
  dnf install \
    --assumeyes \
    --nodocs \
    shadow-utils-2:4.9-12.amzn2023.0.4 \
    python3.12-3.12.11-2.amzn2023.0.2
# shadow-utils provides useradd

RUN useradd --shell /usr/bin/bash --home /hello_api --user-group --uid 1011 hello_api
USER hello_api
WORKDIR /hello_api

ENV VIRTUAL_ENV="/hello_api/python_venv"
RUN python3.12 -m venv "${VIRTUAL_ENV}"
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  --mount=type=cache,target=/root/.cache/pip \
  pip install --upgrade pip==25.2 \
  && pip install --requirement /tmp/requirements.txt

COPY \
  hello_api.openapi.yaml \
  hello_api.py \
  ./

EXPOSE 8000/tcp
CMD [ "gunicorn", "--log-level", "error", "--error-logfile", "-", "--access-logfile", "-", "--bind", "0.0.0.0:8000", "--worker-class", "uvicorn.workers.UvicornWorker", "hello_api:hello_api_app" ]
