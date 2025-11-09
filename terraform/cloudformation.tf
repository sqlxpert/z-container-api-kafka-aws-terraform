# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin



# https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html#creating-shareable-events
# https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events

resource "aws_schemas_registry" "lambda_testevent" {
  for_each = toset(
    var.enable_kafka
    ? [local.lambda_testevent_schemas_registry_name]
    : []
  )

  region = local.aws_region_main
  name   = each.key

  lifecycle {
    prevent_destroy = true
    # Retain this registry when destroying project-specific resources, because
    # it holds test event schemas for ALL Lambda functions in an AWS account
    # and region.
    #
    # terraform state rm 'aws_schemas_registry.lambda_testevent'
    #
    # or, add a removed block with lifecycle.destroy = false
    # https://developer.hashicorp.com/terraform/language/block/removed#lifecycle

    ignore_changes = [
      # These properties should always be as defined by AWS (i.e., not set).
      description,
      tags,
      tags_all,
    ]
  }
}

import {
  for_each = toset(
    (var.enable_kafka && !var.create_lambda_testevent_schema_registry)
    ? [local.lambda_testevent_schemas_registry_name]
    : []
  )

  id = join("@", [
    each.key,
    local.aws_region_main
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support#how-region-works
  ])

  to = aws_schemas_registry.lambda_testevent[each.key]
}



resource "aws_cloudformation_stack" "kafka_consumer" {
  count = var.enable_kafka ? 1 : 0

  region        = local.aws_region_main
  name          = "HelloApiKafkaConsumer"
  template_body = file("${local.cloudformation_path}/kafka_consumer.yaml")

  capabilities = ["CAPABILITY_IAM"]

  depends_on = [
    aws_schemas_registry.lambda_testevent,
  ]

  parameters = {
    # Terraform won't automatically convert HCL list(string) to
    # CloudFormation List<String> !
    # Error: Inappropriate value for attribute "parameters": element
    # "[...]": string required, but have list of string.
    LambdaFnSubnetIds = join(",",
      module.hello_vpc_subnets.private_subnet_ids
    )
    LambdaFnSecurityGroupIds = join(",",
      [
        aws_security_group.hello["lambda_function"].id,
      ]
    )

    MskClusterArn   = aws_msk_serverless_cluster.hello_api[0].arn
    MskClusterTopic = var.kafka_topic

    LogLevel = "INFO"

    # I am not initially supporting KMS encryption for this VPC Lambda
    # function housed in private subnets, due to the cost of interface
    # endpoints for even more services!
    # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-vpc-privatelink
    # https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-endpoints.html
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html#create-vpc-endpoints
    SqsKmsKey            = null
    CloudWatchLogsKmsKey = null
  }

  tags = {
    cloudformation = "1"
    source         = "github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws/tree/main/terraform/cloudformation.tf"
  }
}
