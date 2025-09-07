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

  lifecycle {
    ignore_changes = [
      cidr
    ]
  }

  ipam_pool_id = aws_vpc_ipam_pool.hello_api_vpc_subnets.id
}
resource "aws_vpc_ipam_pool_cidr_allocation" "hello_api_vpc_public_subnets" {
  count = local.hello_api_vpc_private_subnet_count

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
    private = [
      for cidr_allocation in aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_private_subnets :
      cidr_allocation.cidr
    ]
    public = [
      for cidr_allocation in aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_public_subnets :
      cidr_allocation.cidr
    ]
  }]

  max_subnet_count = local.hello_api_vpc_private_subnet_count
  # Maximum subnets per type (public or private), not overall!

  public_route_table_enabled            = true
  public_route_table_per_subnet_enabled = false
  nat_gateway_enabled                   = true
  max_nats                              = 1
}
