# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

output "hello_api_aws_ecr_registry_region" {
  value       = aws_ecr_repository.hello_api.region
  description = "AWS region code for hello_api resources"
  sensitive   = false
  ephemeral   = false
}

output "hello_api_aws_ecr_registry_uri" {
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region_main}.amazonaws.com"
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
  value       = aws_lb.hello_api.dns_name
  description = "Domain name (on the public Internet) of the hello_api load balancer. Use this to connect."
  sensitive   = false
  ephemeral   = false
}
