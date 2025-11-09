# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin



resource "aws_vpc_ipam" "hello_vpc" {
  description = "hello VPC"

  region = local.aws_region_main
  operating_regions {
    region_name = local.aws_region_main
  }
}



resource "aws_vpc_ipam_pool" "hello_vpc" {
  description = "hello VPC private addresses"

  locale        = local.aws_region_main
  region        = local.aws_region_main
  ipam_scope_id = aws_vpc_ipam.hello_vpc.private_default_scope_id

  address_family = "ipv4"
  auto_import    = false
}

resource "aws_vpc_ipam_pool_cidr" "hello_vpc" {
  region       = local.aws_region_main
  ipam_pool_id = aws_vpc_ipam_pool.hello_vpc.id

  cidr = "${var.vpc_ipv4_cidr_block_start}/${var.vpc_netmask_length}"

  # Normally this would be a resource planning pool derived from a VPC, but
  # as of 2025-09, the Terraform AWS provider does not support SourceResource .
  # https://docs.aws.amazon.com/vpc/latest/ipam/tutorials-subnet-planning.html
  # https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-ec2-ipampool.html#cfn-ec2-ipampool-sourceresource
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool
}

module "hello_vpc" {
  source  = "cloudposse/vpc/aws"
  version = "3.0.0"

  name    = "hello"
  enabled = true

  ipv4_primary_cidr_block          = aws_vpc_ipam_pool_cidr.hello_vpc.cidr
  assign_generated_ipv6_cidr_block = false

  default_security_group_deny_all = true
}



resource "aws_vpc_ipam_pool" "hello_vpc_subnets" {
  description = "hello VPC subnet private addresses"

  locale              = local.aws_region_main
  region              = local.aws_region_main
  source_ipam_pool_id = aws_vpc_ipam_pool.hello_vpc.id
  ipam_scope_id       = aws_vpc_ipam.hello_vpc.private_default_scope_id

  address_family                    = "ipv4"
  allocation_default_netmask_length = var.vpc_subnet_netmask_length
  auto_import                       = false
}

resource "aws_vpc_ipam_pool_cidr" "hello_vpc_subnets" {
  region       = local.aws_region_main
  ipam_pool_id = aws_vpc_ipam_pool.hello_vpc_subnets.id
  cidr         = aws_vpc_ipam_pool_cidr.hello_vpc.cidr
}

locals {
  subnet_scope_to_keys = {
    for subnet_scope in ["private", "public"] :
    subnet_scope => [
      for subnet_index in range(var.vpc_private_subnet_count) :
      join(":", [subnet_scope, subnet_index])
    ]
  }
  subnet_keys_set = toset(flatten(values(local.subnet_scope_to_keys)))
}

resource "aws_vpc_ipam_pool_cidr_allocation" "hello_vpc_subnets" {
  for_each = local.subnet_keys_set

  description = "hello VPC ${each.key} subnet private addresses"

  depends_on = [
    aws_vpc_ipam_pool_cidr.hello_vpc_subnets,
  ]

  lifecycle {
    ignore_changes = [
      description,
      cidr,
    ]
  }

  region       = local.aws_region_main
  ipam_pool_id = aws_vpc_ipam_pool.hello_vpc_subnets.id
}

module "hello_vpc_subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.2"

  name    = "hello"
  enabled = true

  vpc_id = module.hello_vpc.vpc_id
  igw_id = [module.hello_vpc.igw_id]
  ipv4_cidrs = [{
    for subnet_scope, subnet_keys in local.subnet_scope_to_keys :
    subnet_scope => [
      for subnet_key in subnet_keys :
      aws_vpc_ipam_pool_cidr_allocation.hello_vpc_subnets[subnet_key].cidr
    ]
  }]

  max_subnet_count = var.vpc_private_subnet_count
  # Maximum subnets per type (public or private), not overall!

  public_route_table_enabled            = true
  public_route_table_per_subnet_enabled = false
  nat_gateway_enabled                   = var.create_nat_gateway
  max_nats                              = 1
}



locals {
  endpoint_type_to_service_to_clients = {

    "Custom" = {
      "hello_api_public"  = []
      "hello_api_private" = ["hello_api_private_client"]
      "kafka"             = ["kafka_client", "msk_lambda_function"]
    }

    "Gateway" = {
      "s3" = ["ecs_task"]
    }

    "Interface" = merge(
      {
        "ecr.api" = ["ecs_task"]
        "ecr.dkr" = ["ecs_task"]
        "logs"    = ["ecs_task", "lambda_function"]
        "sqs"     = ["lambda_function"]
        "lambda"  = ["msk_lambda_function"]
        "sts"     = ["msk_lambda_function"]
      },
      var.enable_ecs_exec ? { "ssmmessages" = ["ecs_task"] } : {},
    )
  }

  endpoint_type_to_services_set = {
    for endpoint_type, service_to_clients
    in local.endpoint_type_to_service_to_clients :
    endpoint_type => toset(keys(service_to_clients))
  }

  aws_service_to_endpoint_type = merge([
    for endpoint_type, services_set in local.endpoint_type_to_services_set :
    {
      for service in services_set :
      service => endpoint_type
    }
    if contains(["Gateway", "Interface"], endpoint_type)
  ]...)

  endpoint_clients_set = toset(flatten([
    for endpoint_type, service_to_clients
    in local.endpoint_type_to_service_to_clients :
    values(service_to_clients)
  ]))

  security_group_keys_set = setunion(
    local.endpoint_clients_set,
    local.endpoint_type_to_services_set["Custom"],
    local.endpoint_type_to_services_set["Interface"],
  )

  endpoint_type_to_flows = {
    for endpoint_type, service_to_clients
    in local.endpoint_type_to_service_to_clients :
    endpoint_type => merge([
      for service, clients in service_to_clients :
      {
        for client in clients :
        join(":", [client, service]) => {
          "client" : client
          "service" : service
          "endpoint_type" = endpoint_type # No ../ back-reference, so duplicate
        }
      }
    ]...)
  }
}



# I hate wasting my time writing, and your time having you read, duplicate
# information. I don't write security group rule descriptions because rules are
# self-describing. For security group names, I can update the Name tag without
# replacing the security group (which fails, or interrupts network traffic, if
# not done in multiple steps). I am reluctantly duplicating Name tag values as
# custom security group physical names because, in the AWS Console, security
# group rules show the physical names of referenced security groups.

resource "aws_security_group" "hello" {
  for_each = local.security_group_keys_set

  lifecycle {
    ignore_changes = [
      name,
      description,
      # A change to either of these would require deletion and re-creation of
      # the security group, untenable while references exist
    ]
  }

  region = local.aws_region_main
  name   = each.key
  tags   = { Name = each.key }
  description = join(" ", [
    trimsuffix(each.key, "_client"),
    contains(local.endpoint_type_to_services_set["Interface"], each.key)
    ? "AWS service PrivateLink VPC interface endpoint"
    : (
      contains(local.endpoint_type_to_services_set["Custom"], each.key)
      ? "custom service endpoint"
      : "(client)"
    ),
    "- hello VPC"
  ])

  vpc_id = module.hello_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "hello" {
  for_each = merge(
    local.endpoint_type_to_flows["Custom"],
    local.endpoint_type_to_flows["Interface"],
  )

  region            = local.aws_region_main
  security_group_id = aws_security_group.hello[each.value["service"]].id

  tags                         = { Name = aws_security_group.hello[each.value["client"]].tags["Name"] }
  referenced_security_group_id = aws_security_group.hello[each.value["client"]].id
  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports[each.value["service"]]
  to_port                      = local.tcp_ports[each.value["service"]]
}

resource "aws_vpc_security_group_egress_rule" "hello" {
  for_each = merge(
    local.endpoint_type_to_flows["Custom"],
    local.endpoint_type_to_flows["Interface"],

    var.create_vpc_endpoints_and_load_balancer
    ? local.endpoint_type_to_flows["Gateway"]
    : {},
  )

  region            = local.aws_region_main
  security_group_id = aws_security_group.hello[each.value["client"]].id

  ip_protocol = "tcp"
  from_port   = local.tcp_ports[each.value["service"]]
  to_port     = local.tcp_ports[each.value["service"]]

  referenced_security_group_id = (
    contains(["Custom", "Interface"], each.value["endpoint_type"])
    ? aws_security_group.hello[each.value["service"]].id
    : null
  )

  prefix_list_id = (
    each.value["endpoint_type"] == "Gateway"
    ? aws_vpc_endpoint.hello[each.value["service"]].prefix_list_id
    : null
  )
  # https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html#gateway-endpoint-security
  # https://docs.aws.amazon.com/vpc/latest/userguide/working-with-aws-managed-prefix-lists.html#available-aws-managed-prefix-lists

  tags = { Name = each.value["service"] }
}



resource "aws_vpc_endpoint" "hello" {
  for_each = (
    var.create_vpc_endpoints_and_load_balancer
    ? local.aws_service_to_endpoint_type
    : {}
  )

  vpc_endpoint_type = each.value

  region = local.aws_region_main # service_region defaults to region
  service_name = join(".", [
    "com",
    "amazonaws",
    local.aws_region_main,
    each.key
  ])

  subnet_ids          = each.value == "Interface" ? module.hello_vpc_subnets.private_subnet_ids : null
  security_group_ids  = each.value == "Interface" ? [aws_security_group.hello[each.key].id] : null
  private_dns_enabled = each.value == "Interface" ? true : null

  route_table_ids = each.value == "Gateway" ? module.hello_vpc_subnets.private_route_table_ids : null

  vpc_id = module.hello_vpc.vpc_id
}



resource "aws_vpc_security_group_ingress_rule" "hello_public" {
  for_each = toset(keys(local.public_protocol_redirect))

  region            = local.aws_region_main
  security_group_id = aws_security_group.hello["hello_api_public"].id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = local.tcp_ports[each.key]
  to_port     = local.tcp_ports[each.key]
}
