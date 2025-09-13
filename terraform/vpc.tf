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
    region_name = var.aws_region_main
  }
}

resource "aws_vpc_ipam_pool" "hello_api_vpc" {
  ipam_scope_id = aws_vpc_ipam.hello_api_vpc.private_default_scope_id
  locale        = var.aws_region_main

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
  locale              = var.aws_region_main

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



resource "aws_security_group" "hello_api_vpc_all_egress" {
  vpc_id = module.hello_api_vpc.vpc_id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "hello_api_load_balancer_from_source" {
  vpc_id = module.hello_api_vpc.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

resource "aws_security_group" "hello_api_load_balancer_to_target" {
  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_security_group" "hello_api_load_balancer_target" {
  vpc_id = module.hello_api_vpc.vpc_id

  ingress {
    security_groups = [aws_security_group.hello_api_load_balancer_to_target.id]
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
  }
}

resource "aws_vpc_security_group_egress_rule" "hello_api_load_balancer_to_target" {
  security_group_id = aws_security_group.hello_api_load_balancer_to_target.id

  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.hello_api_load_balancer_target.id
}

# https://docs.aws.amazon.com/msk/latest/developerguide/port-info.html

resource "aws_security_group" "hello_api_kafka_client" {
  vpc_id = module.hello_api_vpc.vpc_id
}

resource "aws_security_group" "hello_api_kafka_server" {
  vpc_id = module.hello_api_vpc.vpc_id

  ingress {
    security_groups = [aws_security_group.hello_api_kafka_client.id]
    protocol        = "tcp"
    from_port       = 9098
    to_port         = 9098
  }
}

resource "aws_vpc_security_group_egress_rule" "hello_api_kafka_client" {
  security_group_id = aws_security_group.hello_api_kafka_client.id

  ip_protocol                  = "tcp"
  from_port                    = 9098
  to_port                      = 9098
  referenced_security_group_id = aws_security_group.hello_api_kafka_server.id
}

resource "aws_security_group" "hello_api_vpc_interface_endpoint_kafka" {
  vpc_id = module.hello_api_vpc.vpc_id

  ingress {
    cidr_blocks = [module.hello_api_vpc.vpc_cidr_block]
    protocol    = "tcp"
    from_port   = 9098
    to_port     = 9098
  }
}

resource "aws_security_group" "hello_api_vpc_interface_endpoint_tls" {
  vpc_id = module.hello_api_vpc.vpc_id

  ingress {
    cidr_blocks = [module.hello_api_vpc.vpc_cidr_block]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
}

resource "aws_vpc_endpoint" "hello_api_vpc_s3_gateway" {
  vpc_id = module.hello_api_vpc.vpc_id

  service_name      = "com.amazonaws.${var.aws_region_main}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.hello_api_vpc_subnets.private_route_table_ids
}

# MSK Serverless provides a managed VPC endpoint. "kafka" hooks are for MSK
# Provisioned. Creating a VPC interface endpoint for use with MSK Provisioned
# requires an extra connection acceptance step, for which I was not able to
# find documentation. The error was:
# Error: creating EC2 VPC Endpoint (com.amazonaws.us-west-2.kafka): operation
# error EC2: CreateVpcEndpoint, https responseerror StatusCode: 400, RequestID:
# [...], api error InvalidParameter: Private DNS can only be enabled after the
# endpoint connection is accepted by the owner of
# com.amazonaws.us-west-2.kafka.
# MSK Serverless:
# https://aws.amazon.com/blogs/big-data/secure-connectivity-patterns-for-amazon-msk-serverless-cross-account-access/
# MSK Provisioned:
# https://github.com/hashicorp/terraform-provider-aws/issues/7148

locals {
  vpc_interface_endpoint_service_to_security_group = {
    "ecr.api" = aws_security_group.hello_api_vpc_interface_endpoint_tls.id
    "ecr.dkr" = aws_security_group.hello_api_vpc_interface_endpoint_tls.id
    "logs"    = aws_security_group.hello_api_vpc_interface_endpoint_tls.id
    # "kafka"   = aws_security_group.hello_api_vpc_interface_endpoint_kafka.id
  }
  vpc_interface_endpoint_service_requires_acceptance = toset([
    # "kafka"
  ])
}

resource "aws_vpc_endpoint" "hello_api_vpc_interface" {
  for_each = local.vpc_interface_endpoint_service_to_security_group

  vpc_id = module.hello_api_vpc.vpc_id

  service_name        = "com.amazonaws.${var.aws_region_main}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = contains(local.vpc_interface_endpoint_service_requires_acceptance, each.key) ? null : true
  subnet_ids          = module.hello_api_vpc_subnets.private_subnet_ids
  security_group_ids  = [each.value]
}

resource "aws_vpc_endpoint_private_dns" "hello_api_vpc_interface" {
  for_each = local.vpc_interface_endpoint_service_requires_acceptance

  vpc_endpoint_id     = aws_vpc_endpoint.hello_api_vpc_interface[each.key].id
  private_dns_enabled = true
}
