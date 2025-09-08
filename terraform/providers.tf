# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

provider "aws" {
  region = var.aws_region_main

  default_tags {
    tags = {
      project = "demonstration"
    }
  }
}
