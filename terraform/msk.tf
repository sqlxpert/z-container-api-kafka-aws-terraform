# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

resource "aws_msk_serverless_cluster" "hello_api" {
  count = var.enable_kafka ? 1 : 0

  cluster_name = "hello-api"

  vpc_config {
    subnet_ids = module.hello_api_vpc_subnets.private_subnet_ids
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
