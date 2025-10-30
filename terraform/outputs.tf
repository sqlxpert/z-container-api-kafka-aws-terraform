# Containerized REST API, Kafka, Lambda consumer, via Terraform+CloudFormation
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

output "hello_api_aws_ecr_registry_region" {
  value       = aws_ecr_repository.hello_api.region
  description = "AWS region code for hello_api resources"
  sensitive   = false
  ephemeral   = false
}

output "hello_api_aws_ecr_registry_uri" {
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${aws_ecr_repository.hello_api.region}.amazonaws.com"
  description = "URI of registry containing hello_api Elastic Container Registry repository"
  sensitive   = false
  ephemeral   = false
}

output "hello_api_aws_ecr_repository_url" {
  value       = aws_ecr_repository.hello_api.repository_url
  description = "URL of hello_api Elastic Container Registry repository"
  sensitive   = false
  ephemeral   = false
}

output "hello_api_aws_ecr_image_tag" {
  value       = var.hello_api_aws_ecr_image_tag
  description = "Version tag of hello_api image in Elastic Container Registry repository"
  sensitive   = false
  ephemeral   = false
}

output "hello_api_load_balander_domain_name" {
  value       = try(aws_lb.hello_api[0].dns_name, "NOT_ENABLED")
  description = "Domain name (on the public Internet) of the hello_api load balancer. Use this to connect. If create_vpc_endpoints_and_load_balancer is false , this will read NOT_ENABLED"
  sensitive   = false
  ephemeral   = false
}

output "amazon_linux_base_version" {
  value       = var.amazon_linux_base_version
  description = "The version of the Amazon Linux base image. See https://docs.aws.amazon.com/linux/al2023/ug/base-container.html , https://gallery.ecr.aws/amazonlinux/amazonlinux , and https://github.com/amazonlinux/container-images/blob/al2023/Dockerfile"
  sensitive   = false
  ephemeral   = false
}

output "amazon_linux_base_digest" {
  value       = var.amazon_linux_base_digest
  description = "The digest of the Amazon Linux base image. See https://github.com/amazonlinux/container-images/blob/al2023/Dockerfile"
  sensitive   = false
  ephemeral   = false
}
