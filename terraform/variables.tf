# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

variable "aws_region_main" {
  type        = string
  description = "Main region code for AWS provider. You can override this in individual resource definitions as of v6.0.0 (2025-06-18). See https://registry.terraform.io/providers/hashicorp/aws/6.0.0/docs/guides/enhanced-region-support#whats-new"

  default = "us-west-2"
}

variable "hello_api_aws_ecr_image_tag" {
  type        = string
  description = "Version tag of hello_api image in Elastic Container Registry repository"

  default = "1.0.0"
}
