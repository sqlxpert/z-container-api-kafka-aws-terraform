# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

resource "aws_cloudformation_stack" "kafka_consumer" {
  count = var.enable_kafka ? 1 : 0

  name          = "HelloApiKafkaConsumer"
  template_body = file("${local.cloudformation_path}/kafka_consumer.yaml")

  region = local.region

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    LambdaFnSubnetIds        = module.hello_api_vpc_subnets.private_subnet_ids
    LambdaFnSecurityGroupIds = [aws_security_group.hello["kafka_client"].id, ]
    MskClusterArn            = aws_msk_serverless_cluster.hello_api[0].arn
    MskClusterTopic          = var.kafka_topic

    CreateLambdaTestEvents = true

    # I am not initially supporting KMS encryption for this VPC Lambda
    # function housed in private subnets, due to the cost of interface
    # endpoints for even more services!
    # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-vpc-privatelink
    # https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-endpoints.html
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html#create-vpc-endpoints
    SqsKmsKey            = null
    CloudWatchLogsKmsKey = null
  }
}

