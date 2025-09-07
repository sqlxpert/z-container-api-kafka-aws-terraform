# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

###############################################################################
# TODO: Define new VPC, subnets, and security groups

data "aws_security_group" "hello_api_load_balancer_target" {
  id = "sg-0e9e7260c977a2714"
}

data "aws_subnet" "private_list" {
  for_each = toset([
    "subnet-0cec32cd29b245a7d", # 172.31.32.0/20 us-west-2a
    "subnet-05c7dd591553f9280", # 172.31.16.0/20 us-west-2b
    "subnet-0b261a0f5e89ff296"  # 172.31.0.0/20  us-west-2c
  ])

  id = each.value
}
###############################################################################
