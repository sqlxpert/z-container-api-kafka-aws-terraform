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
