# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin



# https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html#creating-shareable-events
# https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events

locals {
  lambda_testevent_schemas_registry_name = "lambda-testevent-schemas"

  lambda_testevent_schemas_registry_names_set = toset([
    local.lambda_testevent_schemas_registry_name
  ])
}

resource "aws_schemas_registry" "this" {
  for_each = local.lambda_testevent_schemas_registry_names_set

  region      = local.region
  name        = each.key
  description = null # Conforms with Lambda-generated registry

  lifecycle {
    prevent_destroy = true
    # Instead, add a removed block with lifecycle.destroy = false
    # https://developer.hashicorp.com/terraform/language/block/removed#lifecycle
  }
}

import {
  for_each = (
    var.create_lambda_test_event_schema_registry
    ? toset([])
    : local.lambda_testevent_schemas_registry_names_set
  )

  region = local.region
  id     = each.key

  to = aws_schemas_registry.this[each.key]
}



resource "aws_cloudformation_stack" "kafka_consumer" {
  count = var.enable_kafka ? 1 : 0

  name          = "HelloApiKafkaConsumer"
  template_body = file("${local.cloudformation_path}/kafka_consumer.yaml")

  region = local.region

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    # Terraform won't automatically convert HCL list(string) to
    # CloudFormation List<String> !
    # Error: Inappropriate value for attribute "parameters": element
    # "[...]": string required, but have list of string.
    LambdaFnSubnetIds = join(",",
      module.hello_api_vpc_subnets.private_subnet_ids
    )
    LambdaFnSecurityGroupIds = join(",",
      [
        aws_security_group.hello["lambda_function"].id,
        aws_security_group.hello["kafka_client"].id,
      ]
    )

    MskClusterArn   = aws_msk_serverless_cluster.hello_api[0].arn
    MskClusterTopic = var.kafka_topic

    # I am not initially supporting KMS encryption for this VPC Lambda
    # function housed in private subnets, due to the cost of interface
    # endpoints for even more services!
    # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-vpc-privatelink
    # https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-endpoints.html
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html#create-vpc-endpoints
    SqsKmsKey            = null
    CloudWatchLogsKmsKey = null
  }
}

