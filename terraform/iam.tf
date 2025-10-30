# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin



data "aws_iam_policy_document" "hello_api_ecs_task_execution_assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "hello_api_ecs_task_assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.aws_partition}:ecs:${local.aws_region_main}:${local.aws_account_id}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.aws_account_id]
    }
  }
}



locals {
  roles = {

    "hello_api_ecs_task_execution" = {
      assume_role_policy = data.aws_iam_policy_document.hello_api_ecs_task_execution_assume_role
      aws_policy_names = [
        "AmazonECSTaskExecutionRolePolicy",
      ]
    }

    "hello_api_ecs_task" = {
      assume_role_policy = data.aws_iam_policy_document.hello_api_ecs_task_assume_role
      aws_policy_names = [
      ]
    }
  }

  aws_policy_names_set = toset(
    flatten(values(local.roles)[*]["aws_policy_names"])
  )

  role_policy_attachments = flatten([
    for role_name, role_detail
    in local.roles : [
      for aws_policy_name
      in role_detail["aws_policy_names"] :
      {
        "role_name"       = role_name
        "aws_policy_name" = aws_policy_name
      }
  ]])

  role_policy_attachments_map = {
    for attach in local.role_policy_attachments :
    join(":", [attach["role_name"], attach["aws_policy_name"]]) => attach
  }
}

resource "aws_iam_role" "hello" {
  for_each = local.roles

  name = each.key

  assume_role_policy = each.value.assume_role_policy.json
}

data "aws_iam_policy" "aws" {
  for_each = local.aws_policy_names_set

  name = each.key
}

resource "aws_iam_role_policy_attachment" "hello_aws" {
  for_each = local.role_policy_attachments_map

  role       = each.value["role_name"]
  policy_arn = data.aws_iam_policy.aws[each.value["aws_policy_name"]].arn

  depends_on = [
    aws_iam_role.hello,
  ]
}



# https://docs.aws.amazon.com/msk/latest/developerguide/create-iam-role.html
# https://docs.aws.amazon.com/service-authorization/latest/reference/list_apachekafkaapisforamazonmskclusters.html#apachekafkaapisforamazonmskclusters-actions-as-permissions
# https://aws.amazon.com/blogs/big-data/amazon-msk-serverless-now-supports-kafka-clients-written-in-all-programming-languages/

data "aws_iam_policy_document" "kafka_write" {
  count = var.enable_kafka ? 1 : 0

  statement {
    actions = [
      "kafka:GetBootstrapBrokers",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "kafka:DescribeClusterV2",
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
    ]
    resources = [aws_msk_serverless_cluster.hello_api[0].arn]
  }
  statement {
    actions = [
      "kafka-cluster:CreateTopic",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData",
    ]
    resources = [join("/", [
      replace(aws_msk_serverless_cluster.hello_api[0].arn, ":cluster/", ":topic/"),
      var.kafka_topic
    ])]
  }
  statement {
    actions = [
      "kafka-cluster:DescribeGroup",
      "kafka-cluster:AlterGroup",
    ]
    resources = [join("/", [
      replace(aws_msk_serverless_cluster.hello_api[0].arn, ":cluster/", ":group/"),
      "*"
    ])]
  }
}

resource "aws_iam_policy" "kafka_write" {
  count = var.enable_kafka ? 1 : 0

  name        = "kafka_write"
  description = "MSK hello_api cluster: create, write to '{$var.kafka_topic}' topic"

  policy = data.aws_iam_policy_document.kafka_write[0].json
}

resource "aws_iam_role_policy_attachment" "hello_api_ecs_task_kafka_write" {
  count = var.enable_kafka ? 1 : 0

  role       = aws_iam_role.hello["hello_api_ecs_task"].name
  policy_arn = aws_iam_policy.kafka_write[0].arn
}
