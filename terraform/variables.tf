# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

variable "aws_region_main" {
  type        = string
  description = "Region code in which to create AWS resources. The empty string causes the module to use the default region configured for the Terraform AWS provider. Do not change this until all resource definitions have been made region-aware to take advantage of enhanced region support in v6.0.0 of the Terraform AWS provider."

  default = ""
}

variable "hello_api_aws_ecr_image_tag" {
  type        = string
  description = "Version tag of hello_api image in Elastic Container Registry repository"

  default = "1.0.0"
}

variable "enable_kafka" {
  type        = bool
  description = "Whether to create the MSK Serverless cluster and have hello_api write to it. Change to false to significantly reduce costs."

  default = false
}

variable "hello_api_aws_ecs_service_desired_count_tasks" {
  type        = number
  description = "Number of hello_api Elastic Container Service tasks desired. Reduce to 0 to pause the service."

  default = 3
}

variable "enable_https" {
  type        = bool
  description = "Whether to generate a self-signed TLS certificate (subject to Web browser warnings), enable HTTPS, and redirect HTTP to HTTPS. In case of problems, set to false for ordinary HTTP. Changing this might require repeating `terraform apply`, because there is no destroy-before-create feature to regulate replacing a listener on the same port. Your Web browser might force continued use of HTTPS."

  default = true
}

variable "create_nat_gateway" {
  type        = bool
  description = "Whether to create a NAT Gateway (expensive). Gateway and interface endpoints, defined to support ECS Fargate, make the NAT Gateway unnecessary."

  default = false
}
