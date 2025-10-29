# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

locals {
  hello_api_vpc_netmask_length        = 21
  hello_api_vpc_subnet_netmask_length = 24
  hello_api_vpc_private_subnet_count  = 3
}



resource "aws_vpc_ipam" "hello_api_vpc" {
  operating_regions {
    region_name = local.aws_region_main
  }
}

resource "aws_vpc_ipam_pool" "hello_api_vpc" {
  ipam_scope_id = aws_vpc_ipam.hello_api_vpc.private_default_scope_id
  locale        = local.aws_region_main

  address_family = "ipv4"

  auto_import = false
}
resource "aws_vpc_ipam_pool_cidr" "hello_api_vpc" {
  ipam_pool_id = aws_vpc_ipam_pool.hello_api_vpc.id

  cidr = "10.11.0.0/${local.hello_api_vpc_netmask_length}"

  # Normally this would be a resource planning pool derived from a VPC, but
  # as of 2025-09, the Terraform AWS provider does not support SourceResource .
  # https://docs.aws.amazon.com/vpc/latest/ipam/tutorials-subnet-planning.html
  # https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-ec2-ipampool.html#cfn-ec2-ipampool-sourceresource
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool
}

module "hello_api_vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.3.0"

  name    = "hello_api"
  enabled = true

  ipv4_primary_cidr_block          = aws_vpc_ipam_pool_cidr.hello_api_vpc.cidr
  assign_generated_ipv6_cidr_block = false

  default_security_group_deny_all = true
}



resource "aws_vpc_ipam_pool" "hello_api_vpc_subnets" {
  source_ipam_pool_id = aws_vpc_ipam_pool.hello_api_vpc.id
  ipam_scope_id       = aws_vpc_ipam.hello_api_vpc.private_default_scope_id
  locale              = local.aws_region_main

  address_family = "ipv4"

  auto_import                       = false
  allocation_default_netmask_length = local.hello_api_vpc_subnet_netmask_length
}
resource "aws_vpc_ipam_pool_cidr" "hello_api_vpc_subnets" {
  ipam_pool_id = aws_vpc_ipam_pool.hello_api_vpc_subnets.id
  cidr         = aws_vpc_ipam_pool_cidr.hello_api_vpc.cidr
}

resource "aws_vpc_ipam_pool_cidr_allocation" "hello_api_vpc_private_subnets" {
  count = local.hello_api_vpc_private_subnet_count

  depends_on = [
    aws_vpc_ipam_pool_cidr.hello_api_vpc_subnets
  ]

  lifecycle {
    ignore_changes = [
      cidr
    ]
  }

  ipam_pool_id = aws_vpc_ipam_pool.hello_api_vpc_subnets.id
}
resource "aws_vpc_ipam_pool_cidr_allocation" "hello_api_vpc_public_subnets" {
  count = local.hello_api_vpc_private_subnet_count

  depends_on = [
    aws_vpc_ipam_pool_cidr.hello_api_vpc_subnets
  ]

  lifecycle {
    ignore_changes = [
      cidr
    ]
  }

  ipam_pool_id = aws_vpc_ipam_pool.hello_api_vpc_subnets.id
}

module "hello_api_vpc_subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.2"

  name    = "hello_api"
  enabled = true

  vpc_id = module.hello_api_vpc.vpc_id
  igw_id = [module.hello_api_vpc.igw_id]
  ipv4_cidrs = [{
    private = aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_private_subnets[*].cidr
    public  = aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_public_subnets[*].cidr
  }]

  max_subnet_count = local.hello_api_vpc_private_subnet_count
  # Maximum subnets per type (public or private), not overall!

  public_route_table_enabled            = true
  public_route_table_per_subnet_enabled = false
  nat_gateway_enabled                   = var.create_nat_gateway
  max_nats                              = 1
}



# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#task-execution-ecr-conditionkeys
# https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html



locals {
  endpoint_service_to_type = {
    "s3"                = "Gateway"
    "hello_api_public"  = "Interface"
    "hello_api_private" = "Interface"
    "kafka"             = "Interface"
    "ecr.api"           = "Interface"
    "ecr.dkr"           = "Interface"
    "logs"              = "Interface"
    "lambda"            = "Interface"
    "sqs"               = "Interface"
    "sts"               = "Interface"
  }
  endpoint_services_set = toset(keys(local.endpoint_service_to_type))
  endpoint_types_set    = toset(values(local.endpoint_service_to_type))

  custom_endpoint_services_set = toset([
    "hello_api_public",
    "hello_api_private",
    "kafka", # MSK Serverless creates its own endpoint
  ])

  standard_endpoint_service_to_type = {
    for endpoint_service in setsubtract(
      local.endpoint_services_set,
      local.custom_endpoint_services_set
    ) : endpoint_service => local.endpoint_service_to_type[endpoint_service]
  }

  endpoint_flows = [

    { client = "hello_api_private_client", service = "hello_api_private" },

    { client = "kafka_client", service = "kafka" },

    # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html#fargate-ecs-vpc-endpoint-considerations
    # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch-logs-and-interface-VPC.html
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html
    { client = "ecs_task", service = "s3" },
    { client = "ecs_task", service = "ecr.api" },
    { client = "ecs_task", service = "ecr.dkr" },
    { client = "ecs_task", service = "logs" },

    # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-network-requirements
    { client = "msk_lambda_function", service = "kafka" },
    { client = "msk_lambda_function", service = "lambda" },
    { client = "msk_lambda_function", service = "sts" },

    # https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-endpoints.html#vpc-endpoint-create
    # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-vpc-privatelink
    # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-internetwork-traffic-privacy.html
    { client = "lambda_function", service = "lambda" },
    { client = "lambda_function", service = "sqs" },
    { client = "lambda_function", service = "logs" },
  ]

  endpoint_clients_set = toset(local.endpoint_flows[*]["client"])

  endpoint_type_to_flows_map = {
    for endpoint_type in local.endpoint_types_set :
    endpoint_type => {
      for endpoint in local.endpoint_flows :
      join(":", [endpoint["client"], endpoint["service"]]) => endpoint
      if endpoint_type == local.endpoint_service_to_type[endpoint["service"]]
    }
  }

  endpoint_type_to_services = {
    for endpoint_service, endpoint_type in local.endpoint_service_to_type :
    endpoint_type => endpoint_service...
  }
  endpoint_type_to_services_set = {
    for endpoint_type, endpoint_services in local.endpoint_type_to_services :
    endpoint_type => toset(endpoint_services)
  }
}



resource "aws_security_group" "hello" {
  for_each = setunion(
    local.endpoint_clients_set,
    local.endpoint_type_to_services_set["Interface"],
  )

  tags = { Name = join("", ["hello_", each.key]) }

  vpc_id = module.hello_api_vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "hello" {
  for_each = local.endpoint_type_to_flows_map["Interface"]

  security_group_id = aws_security_group.hello[each.value["service"]].id

  tags                         = { Name = aws_security_group.hello[each.value["client"]].tags["Name"] }
  referenced_security_group_id = aws_security_group.hello[each.value["client"]].id
  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports[each.value["service"]]
  to_port                      = local.tcp_ports[each.value["service"]]
}

resource "aws_vpc_security_group_egress_rule" "hello" {
  for_each = aws_vpc_security_group_ingress_rule.hello

  security_group_id = each.value.referenced_security_group_id

  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  referenced_security_group_id = each.value.security_group_id
  tags                         = { Name = join("", ["hello_", split(":", each.key)[1]]) }
}



resource "aws_vpc_endpoint" "hello" {
  for_each = (
    var.create_vpc_endpoints_and_load_balancer
    ? local.standard_endpoint_service_to_type
    : {}
  )

  vpc_endpoint_type = each.value
  service_name = join(".", [
    "com",
    "amazonaws",
    local.aws_region_main,
    each.key
  ])

  vpc_id = module.hello_api_vpc.vpc_id

  subnet_ids          = each.value == "Interface" ? module.hello_api_vpc_subnets.private_subnet_ids : null
  security_group_ids  = each.value == "Interface" ? [aws_security_group.hello[each.key].id] : null
  private_dns_enabled = each.value == "Interface" ? true : null

  route_table_ids = each.value == "Gateway" ? module.hello_api_vpc_subnets.private_route_table_ids : null
}



# https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html#gateway-endpoint-security
# https://docs.aws.amazon.com/vpc/latest/userguide/working-with-aws-managed-prefix-lists.html#available-aws-managed-prefix-lists

resource "aws_vpc_security_group_egress_rule" "hello_gateway" {
  for_each = (
    var.create_vpc_endpoints_and_load_balancer
    ? local.endpoint_type_to_flows_map["Gateway"]
    : {}
  )

  security_group_id = aws_security_group.hello[each.value["client"]].id

  ip_protocol    = "tcp"
  from_port      = local.tcp_ports[each.value["service"]]
  to_port        = local.tcp_ports[each.value["service"]]
  prefix_list_id = aws_vpc_endpoint.hello[each.value["service"]].prefix_list_id
  tags           = { Name = each.value["service"] }
}



resource "aws_vpc_security_group_ingress_rule" "hello_public" {
  for_each = toset(var.enable_https ? ["https", "http"] : ["http"])

  security_group_id = aws_security_group.hello["hello_api_public"].id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = local.tcp_ports[each.key]
  to_port     = local.tcp_ports[each.key]
}
