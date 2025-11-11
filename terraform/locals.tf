# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  caller_arn_parts = provider::aws::arn_parse(
    data.aws_caller_identity.current.arn
  )
  # Provider functions added in Terraform v1.8.0
  # arn_parse added in Terraform AWS provider v5.40.0

  aws_partition  = local.caller_arn_parts["partition"]
  aws_account_id = local.caller_arn_parts["account_id"]

  aws_region_main = coalesce(
    var.aws_region_main,
    data.aws_region.current.region
  )
  # data.aws_region.region added,
  # data.aws_region.name marked deprecated
  # in Terraform AWS provider v6.0.0

  lambda_testevent_schemas_registry_name = "lambda-testevent-schemas"

  ecr_repository_name = "hello_api"

  hello_api_web_log_group_name      = "/hello/hello_api_web_log"
  hello_api_ecs_exec_log_group_name = "/hello/hello_api_ecs_exec_log"

  tcp_ports = {
    "http"  = 80
    "https" = 443

    "hello_api_private" = 8000

    # https://docs.aws.amazon.com/msk/latest/developerguide/port-info.html
    "kafka" = 9098

    "s3"          = 443
    "ecr.api"     = 443
    "ecr.dkr"     = 443
    "logs"        = 443
    "lambda"      = 443
    "sqs"         = 443
    "sts"         = 443
    "ssmmessages" = 443
  }

  public_protocol_redirect = merge(

    var.create_vpc ? {
      http = false
    } : {},

    (var.create_vpc && var.enable_https) ? {
      https = false
      http  = true
    } : {},
  )

  cloudformation_path = "${path.module}/cloudformation"
}
