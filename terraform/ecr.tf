# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

resource "aws_ecr_repository" "hello" {
  for_each = toset([local.ecr_repository_name])

  region = local.aws_region_main
  name   = each.key

  image_tag_mutability = "MUTABLE"
  # Give the user the option to specify a new version tag for each image
  # upload, but do not force this, as tag immutability would.
  # https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html

  force_delete = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

import {
  for_each = toset(
    var.create_aws_ecr_repository ? [] : aws_ecr_repository.hello
  )

  id = join("@", [
    each.key,
    local.aws_region_main
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support#how-region-works
  ])

  to = aws_ecr_repository.hello[each.key]
}

data "aws_ecr_lifecycle_policy_document" "hello" {
  for_each = toset(
    var.create_aws_ecr_repository ? aws_ecr_repository.hello : []
  )

  rule {
    priority = 1

    selection {
      tag_status      = "tagged"
      tag_prefix_list = ["hello_api"]
      count_type      = "imageCountMoreThan"
      count_number    = 2
    }

    action {
      type = "expire"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "hello" {
  for_each = data.aws_ecr_lifecycle_policy_document.hello

  region     = local.aws_region_main
  repository = aws_ecr_repository.hello[each.key]

  policy = each.value.json
}
