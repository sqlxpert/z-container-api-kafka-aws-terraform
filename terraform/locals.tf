# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

data "aws_region" "current" {}
locals {
  aws_region_main = coalesce(
    var.aws_region_main,
    data.aws_region.current.region
  )
  # data.aws_region.region added,
  # data.aws_region.name marked deprecated
  # in Terraform AWS provider v6.0.0

  tcp_ports = {
    http = 80
    https = 443
    kafka = 9098
    hello_api = 8000
  }
}
