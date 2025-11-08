# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

# Pre-create to be sure log groups are tracked in state, not created by ECS
resource "aws_cloudwatch_log_group" "hello" {
  for_each = toset([
    local.hello_api_web_log_group_name,
    local.hello_api_ecs_exec_log_group_name,
  ])

  region = local.aws_region_main
  name   = each.key

  log_group_class   = "STANDARD"
  retention_in_days = 3
}
