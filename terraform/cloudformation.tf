# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

resource "aws_cloudformation_stack" "kafka_consumer" {
  count = var.enable_kafka ? 1 : 0

  region        = local.aws_region_main
  name          = "HelloApiKafkaConsumer"
  template_body = file("${local.cloudformation_path}/kafka_consumer.yaml")

  capabilities = ["CAPABILITY_IAM"]

  depends_on = [
    aws_schemas_registry.lambda_testevent,
  ]

  parameters = {
    # Terraform won't automatically convert HCL list(string) to
    # CloudFormation List<String> !
    # Error: Inappropriate value for attribute "parameters": element
    # "[...]": string required, but have list of string.
    LambdaFnSubnetIds = join(",",
      module.hello_vpc_subnets.private_subnet_ids
    )
    LambdaFnSecurityGroupIds = join(",",
      [
        aws_security_group.hello["lambda_function"].id,
      ]
    )

    MskClusterArn   = aws_msk_serverless_cluster.hello_api[0].arn
    MskClusterTopic = var.kafka_topic

    LogLevel = "INFO"

    # I am not initially supporting KMS encryption for this VPC Lambda
    # function housed in private subnets, due to the cost of interface
    # endpoints for even more services!
    # https://docs.aws.amazon.com/lambda/latest/dg/with-msk-cluster-network.html#msk-vpc-privatelink
    # https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-endpoints.html
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html#create-vpc-endpoints
    SqsKmsKey            = null
    CloudWatchLogsKmsKey = null
  }

  tags = {
    cloudformation = "1"
    source         = "github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws/tree/main/terraform/cloudformation.tf"
  }
}
