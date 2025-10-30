# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

variable "aws_region_main" {
  type        = string
  description = "Region code in which to create AWS resources. The empty string causes the module to use the default region configured for the Terraform AWS provider. Do not change this until all resource definitions have been made region-aware to take advantage of enhanced region support in v6.0.0 of the Terraform AWS provider. Non-region-aware modules will pose a problem."

  default = ""
}

variable "hello_api_aws_ecr_image_tag" {
  type        = string
  description = "Version tag of hello_api image in Elastic Container Registry repository"

  default = "1.0.0"
}

variable "enable_kafka" {
  type        = bool
  description = "Whether to create the MSK Serverless cluster. Set this to false to significantly reduce costs; the API will write only to the CloudWatch log. You must set this to false if create_vpc_endpoints_and_load_balancer is false ."

  default = false
}

variable "kafka_topic" {
  type        = string
  description = "Kafka topic to write to and read from"

  default = "events"
}

variable "hello_api_aws_ecs_service_desired_count_tasks" {
  type        = number
  description = "Number of hello_api Elastic Container Service tasks desired. Reduce to 0 to pause the API. You must set this to 0 if create_vpc_endpoints_and_load_balancer is false ."

  default = 2
}

variable "create_vpc_endpoints_and_load_balancer" {
  type        = bool
  description = "Whether to create the virtual private cloud (VPC) interface and gateway endpoints and the application load balancer. These expensive resources are not needed until you have built and uploaded the hello_api image and are ready to start the API. You must set this to true if enable_kafka is true or hello_api_aws_ecs_service_desired_count_tasks is greater than 0."

  default = true

  validation {
    error_message = "Before setting enable_kafka to true or increasing hello_api_aws_ecs_service_desired_count_tasks above 0, you must create the virtual private cloud (VPC) interface and gateway endpoints and an application load balancer."

    condition = (
      (
        (var.hello_api_aws_ecs_service_desired_count_tasks < 1)
        && !var.enable_kafka
      ) || var.create_vpc_endpoints_and_load_balancer
    )
  }
}

variable "enable_https" {
  type        = bool
  description = "Whether to generate a self-signed TLS certificate (subject to Web browser warnings), enable HTTPS, and redirect HTTP to HTTPS. In case of problems, set to false for ordinary HTTP. Changing this might require repeating `terraform apply`, because there is no destroy-before-create feature to regulate replacing a listener on the same port. Your Web browser might force continued use of HTTPS."

  default = true
}

variable "create_lambda_testevent_schema_registry" {
  type        = bool
  description = "Whether to create the EventBridge schema registry that houses shareable test events for all AWS sLambda functions. If running terraform apply with this set to true yields a \"Registry with name lambda-testevent-schemas already exists\" error, change the value to false to import the existing registry. This registry will already exist if a shareable test event has ever been created for any Lambda function in the current AWS account and region."

  default = true
}

variable "create_nat_gateway" {
  type        = bool
  description = "Whether to create a NAT Gateway (expensive). Gateway and interface endpoints, defined to support ECS Fargate, make the NAT Gateway unnecessary."

  default = false
}

variable "amazon_linux_base_version" {
  type        = string
  description = "The version of the Amazon Linux base image. See docs.aws.amazon.com/linux/al2023/ug/base-container.html , gallery.ecr.aws/amazonlinux/amazonlinux , and github.com/amazonlinux/container-images/blob/al2023/Dockerfile"

  default = "2023.8.20250818.0"
}

variable "amazon_linux_base_digest" {
  type        = string
  description = "The digest of the Amazon Linux base image. See github.com/amazonlinux/container-images/blob/al2023/Dockerfile"

  default = "sha256:f5077958231a41decbd60c59c48cdb30519b77fdd326e829893470e3a8aa2e55"
}
