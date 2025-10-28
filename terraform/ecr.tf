# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

resource "aws_ecr_repository" "hello_api" {
  region               = local.aws_region_main
  name                 = "hello_api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_ecr_lifecycle_policy_document" "hello_api" {
  rule {
    priority = 1

    selection {
      tag_status      = "tagged"
      tag_prefix_list = ["hello_api"]
      count_type      = "imageCountMoreThan"
      count_number    = 5
    }

    action {
      type = "expire"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "hello_api" {
  region     = local.aws_region_main
  repository = aws_ecr_repository.hello_api.name

  policy = data.aws_ecr_lifecycle_policy_document.hello_api.json
}
