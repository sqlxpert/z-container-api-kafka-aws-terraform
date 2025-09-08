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

variable "hello_api_aws_ecs_service_desired_count_tasks" {
  type        = number
  description = "Number of hello_api Elastic Container Service tasks desired. Reduce to 0 to pause the service."

  default = 3
}

variable "enable_https" {
  type        = bool
  description = "Whether to generate a self-signed TLS certificate (subject to Web browser warnings), enable HTTPS, and redirect HTTP to HTTPS. In case of problems, set to false for ordinary HTTP. Changing this might require a second `terraform apply`, because there is no lifecycle.destroy_before_create option to regulate replacement of the HTTP listener. Your Web browser might force continued use of HTTPS."

  default = true
}

variable "create_nat_gateway" {
  type        = bool
  description = "Whether to create a NAT Gateway (expensive). Gateway and interface endpoints, defined to support ECS Fargate, make the NAT Gateway unnecessary."

  default = false
}
