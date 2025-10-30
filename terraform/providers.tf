# Containerized REST API, Kafka, Lambda consumer, via Terraform+CloudFormation
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

provider "aws" {
  # AWS_REGION or AWS_DEFAULT_REGION environment variable determines
  # provider's default region.
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference

  default_tags {
    tags = {
      terraform = "1"
      source    = "github.com/sqlxpert/z-container-api-kafka-aws-terraform/tree/main/terraform"
      author    = "Paul Marcelin"
    }
  }
}
