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



resource "aws_security_group" "hello_api_load_balancer_outside" {
  tags = { Name = "hello_api_load_balancer_outside" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "hello_api_load_balancer_outside_http" {
  security_group_id = aws_security_group.hello_api_load_balancer_outside.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = local.tcp_ports["http"]
  to_port     = local.tcp_ports["http"]
}

resource "aws_vpc_security_group_ingress_rule" "hello_api_load_balancer_outside_https" {
  security_group_id = aws_security_group.hello_api_load_balancer_outside.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = local.tcp_ports["https"]
  to_port     = local.tcp_ports["https"]
}



resource "aws_security_group" "hello_api_load_balancer_inside" {
  tags = { Name = "hello_api_load_balancer_inside" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_security_group" "hello_api" {
  tags = { Name = "hello_api" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "hello_api_load_balancer_inside" {
  security_group_id = aws_security_group.hello_api.id

  tags = {
    Name = aws_security_group.hello_api_load_balancer_inside.tags["Name"]
  }

  referenced_security_group_id = aws_security_group.hello_api_load_balancer_inside.id
  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports["hello_api"]
  to_port                      = local.tcp_ports["hello_api"]
}

resource "aws_vpc_security_group_egress_rule" "hello_api_load_balancer_inside" {
  security_group_id = aws_security_group.hello_api_load_balancer_inside.id

  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports["hello_api"]
  to_port                      = local.tcp_ports["hello_api"]
  referenced_security_group_id = aws_security_group.hello_api.id

  tags = { Name = aws_security_group.hello_api.tags["Name"] }
}



# https://docs.aws.amazon.com/msk/latest/developerguide/port-info.html
# https://aws.amazon.com/blogs/big-data/secure-connectivity-patterns-for-amazon-msk-serverless-cross-account-access

resource "aws_security_group" "hello_api_kafka_client" {
  tags = { Name = "hello_api_kafka_client" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_security_group" "hello_api_kafka_server" {
  tags = { Name = "hello_api_kafka_server" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "hello_api_kafka_client" {
  security_group_id = aws_security_group.hello_api_kafka_server.id

  tags = { Name = aws_security_group.hello_api_kafka_client.tags["Name"] }

  referenced_security_group_id = aws_security_group.hello_api_kafka_client.id
  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports["kafka"]
  to_port                      = local.tcp_ports["kafka"]
}

resource "aws_vpc_security_group_egress_rule" "hello_api_kafka_server" {
  security_group_id = aws_security_group.hello_api_kafka_client.id

  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports["kafka"]
  to_port                      = local.tcp_ports["kafka"]
  referenced_security_group_id = aws_security_group.hello_api_kafka_server.id

  tags = { Name = aws_security_group.hello_api_kafka_server.tags["Name"] }
}



# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#task-execution-ecr-conditionkeys
# https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html



resource "aws_security_group" "hello_api_vpc_endpoints_client_ecs_task" {
  tags = { Name = "hello_api_vpc_endpoints_client_ecs_task" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_security_group" "hello_api_vpc_interface_endpoint" {
  for_each = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
  ])

  tags = { Name = "hello_api_vpc_interface_endpoint_${each.key}" }

  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "hello_api_vpc_endpoints_client_ecs_task_interface_endpoint" {
  for_each = aws_security_group.hello_api_vpc_interface_endpoint

  security_group_id = aws_security_group.hello_api_vpc_endpoints_client_ecs_task.id

  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports["https"]
  to_port                      = local.tcp_ports["https"]
  referenced_security_group_id = each.value.id

  tags = { Name = each.value.tags["Name"] }
}

resource "aws_vpc_security_group_ingress_rule" "hello_api_vpc_endpoints_client_ecs_task" {
  for_each = aws_security_group.hello_api_vpc_interface_endpoint

  security_group_id = each.value.id

  tags = {
    Name = aws_security_group.hello_api_vpc_endpoints_client_ecs_task.tags["Name"]
  }

  referenced_security_group_id = aws_security_group.hello_api_vpc_endpoints_client_ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = local.tcp_ports["https"]
  to_port                      = local.tcp_ports["https"]
}

resource "aws_vpc_endpoint" "hello_api_vpc_interface" {
  for_each = (
    var.create_vpc_endpoints_and_load_balancer
    ? aws_security_group.hello_api_vpc_interface_endpoint
    : {}
  )

  vpc_id = module.hello_api_vpc.vpc_id

  subnet_ids          = module.hello_api_vpc_subnets.private_subnet_ids
  security_group_ids  = [each.value.id]
  private_dns_enabled = true
  service_name        = "com.amazonaws.${local.aws_region_main}.${each.key}"
  vpc_endpoint_type   = "Interface"
}



resource "aws_vpc_endpoint" "hello_api_vpc_s3_gateway" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  vpc_id = module.hello_api_vpc.vpc_id

  service_name      = "com.amazonaws.${local.aws_region_main}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.hello_api_vpc_subnets.private_route_table_ids
}

# https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html#gateway-endpoint-security
# https://docs.aws.amazon.com/vpc/latest/userguide/working-with-aws-managed-prefix-lists.html#available-aws-managed-prefix-lists

data "aws_prefix_list" "hello_api_vpc_s3_gateway_endpoint" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  prefix_list_id = aws_vpc_endpoint.hello_api_vpc_s3_gateway[0].prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "hello_api_vpc_endpoints_client_ecs_task_s3_gateway_endpoint" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  security_group_id = aws_security_group.hello_api_vpc_endpoints_client_ecs_task.id

  ip_protocol    = "tcp"
  from_port      = local.tcp_ports["https"]
  to_port        = local.tcp_ports["https"]
  prefix_list_id = data.aws_prefix_list.hello_api_vpc_s3_gateway_endpoint[0].id

  tags = { Name = data.aws_prefix_list.hello_api_vpc_s3_gateway_endpoint[0].name }
}
