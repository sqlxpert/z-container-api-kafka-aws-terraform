# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin



# https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html#creating-shareable-events
# https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events

locals {
  lambda_testevent_schemas_registry_name = "lambda-testevent-schemas"

  schemas_registry_names_set = toset([
    local.lambda_testevent_schemas_registry_name
  ])
}

resource "aws_schemas_registry" "lambda_testevent" {
  for_each = local.schemas_registry_names_set

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
  for_each = (
    var.create_lambda_testevent_schema_registry
    ? toset([])
    : local.schemas_registry_names_set
  )

  id = join("@", [
    each.key,
    local.aws_region_main
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support#how-region-works
  ])

  to = aws_schemas_registry.lambda_testevent[each.key]
}
