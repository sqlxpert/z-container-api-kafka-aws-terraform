# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

provider "aws" {
  # AWS_REGION or AWS_DEFAULT_REGION environment variable determines
  # provider's default region.
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference

  default_tags {
    tags = {
      terraform = "1"
      source    = "github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws/tree/main/terraform"
      author    = "Paul Marcelin"
    }
  }
}
