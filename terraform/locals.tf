# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

data "aws_region" "current" {}
locals {
  aws_region_main = coalesce(
    var.aws_region_main,
    data.aws_region.current.region
  )
  # data.aws_region.region added,
  # data.aws_region.name marked deprecated
  # in Terraform AWS provider v6.0.0

  tcp_ports = {
    "http"  = 80
    "https" = 443

    "hello_api_private" = 8000

    # https://docs.aws.amazon.com/msk/latest/developerguide/port-info.html
    "kafka" = 9098

    "s3"      = 443
    "ecr.api" = 443
    "ecr.dkr" = 443
    "logs"    = 443
    "lambda"  = 443
    "sqs"     = 443
    "sts"     = 443
  }

  cloudformation_path = "${path.module}/cloudformation"
}
