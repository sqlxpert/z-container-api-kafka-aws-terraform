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

  force_delete = var.create_aws_ecr_repository
  # Newly-created repository: Allow deletion even if images are present.
  # Preserved, imported repository: Don't allow deletion unless it's empty.

  encryption_configuration {
    encryption_type = "KMS"
  }
}

import {
  for_each = toset(
    var.create_aws_ecr_repository ? [] : [local.ecr_repository_name]
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
    var.create_aws_ecr_repository ? [local.ecr_repository_name] : []
  )

  rule {
    priority = 1

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = 2
    }

    action {
      type = "expire"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "hello" {
  for_each = toset(
    var.create_aws_ecr_repository ? [local.ecr_repository_name] : []
  )

  region     = local.aws_region_main
  repository = aws_ecr_repository.hello[each.key].name

  policy = data.aws_ecr_lifecycle_policy_document.hello[each.key].json
}
