# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

resource "aws_msk_serverless_cluster" "hello_api" {
  count = var.enable_kafka ? 1 : 0

  region       = local.aws_region_main
  cluster_name = "hello-api"

  vpc_config {
    subnet_ids = module.hello_vpc_subnets.private_subnet_ids
    security_group_ids = [
      aws_security_group.hello["kafka"].id,

      # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-network-requirements
      aws_security_group.hello["msk_lambda_function"].id,
    ]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }
}
