# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

data "aws_caller_identity" "current" {}



# To reduce free labor on this demonstration project, I rely on AWS-managed IAM
# policies, which are overly permissive. For examples of my trademark custom
# least-privilege policies, see my pre-existing open-source projects.
#
# Least-privilege deployment role:
# https://github.com/sqlxpert/lights-off-aws/blob/fe1b565/cloudformation/lights_off_aws_prereq.yaml#L83-L267
#
# Least-privilege Lambda function roles:
# https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L484-L741



data "aws_iam_policy_document" "hello_api_ecs_task_execution_assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "hello_api_ecs_task_execution" {
  name = "hello_api_ecs_task_execution"

  assume_role_policy = data.aws_iam_policy_document.hello_api_ecs_task_execution_assume_role.json
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
      values   = ["arn:aws:ecs:${local.aws_region_main}:${data.aws_caller_identity.current.account_id}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
resource "aws_iam_role" "hello_api_ecs_task" {
  name = "hello_api_ecs_task"

  assume_role_policy = data.aws_iam_policy_document.hello_api_ecs_task_assume_role.json
}



# https://docs.aws.amazon.com/msk/latest/developerguide/create-iam-role.html
# https://docs.aws.amazon.com/service-authorization/latest/reference/list_apachekafkaapisforamazonmskclusters.html#apachekafkaapisforamazonmskclusters-actions-as-permissions
# https://aws.amazon.com/blogs/big-data/amazon-msk-serverless-now-supports-kafka-clients-written-in-all-programming-languages/

data "aws_iam_policy_document" "kafka_write" {
  statement {
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster"
    ]
    resources = [
      try(
        aws_msk_serverless_cluster.hello_api[0].arn,
        "*"
      )
    ]
  }
  statement {
    actions = [
      "kafka-cluster:CreateTopic",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData"
    ]
    resources = [
      try(
        join("/", [
          replace(aws_msk_serverless_cluster.hello_api[0].arn, ":cluster/", ":topic/"),
          var.kafka_topic
        ]),
        "*"
      )
    ]
  }
  statement {
    actions = [
      "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup"
    ]
    resources = [
      try(
        join("/", [
          replace(aws_msk_serverless_cluster.hello_api[0].arn, ":cluster/", ":group/"),
          "*"
        ]),
        "*"
      )
    ]
  }
}
resource "aws_iam_policy" "kafka_write" {
  count = var.enable_kafka ? 1 : 0

  name        = "kafka_write"
  description = "MSK hello_api cluster: create, write to '{$var.kafka_topic}' topic"

  policy = data.aws_iam_policy_document.kafka_write.json
}
resource "aws_iam_role_policy_attachment" "hello_api_ecs_task_kafka_write" {
  count = var.enable_kafka ? 1 : 0

  role       = aws_iam_role.hello_api_ecs_task.name
  policy_arn = one(aws_iam_policy.kafka_write).arn
}



locals {
  iam_role_name_to_aws_managed_iam_policy_names = {

    "hello_api_ecs_task_execution" = [
      "AmazonECSTaskExecutionRolePolicy"
    ]

    "hello_api_ecs_task" = [
    ]
  }

  # The map seeds aws_iam_role_policy_attachment resources, but it could also
  # seed aws_iam_role resources. Expressing role trust policies in HCL object
  # form and calling jsonencode() instead of expressing them in HCL block form
  # in data.aws_iam_policy_document is the tradeoff.

  iam_role_policy_attachments = flatten([
    for iam_role_name, aws_managed_iam_policy_names in local.iam_role_name_to_aws_managed_iam_policy_names : [
      for aws_managed_iam_policy_name in aws_managed_iam_policy_names :
      {
        iam_role_name               = iam_role_name,
        aws_managed_iam_policy_name = aws_managed_iam_policy_name
      }
    ]
  ])

  iam_role_policy_attachments_delimiter = "|"
  iam_role_policy_attachment_strings = toset([
    for iam_role_policy_attachment in local.iam_role_policy_attachments :
    join("", [
      iam_role_policy_attachment.iam_role_name,
      local.iam_role_policy_attachments_delimiter,
      iam_role_policy_attachment.aws_managed_iam_policy_name
    ])
  ])

  aws_managed_iam_policy_names = toset(
    local.iam_role_policy_attachments[*].aws_managed_iam_policy_name
  )
}

data "aws_iam_policy" "aws_managed" {
  for_each = local.aws_managed_iam_policy_names

  name = each.key
}
resource "aws_iam_role_policy_attachment" "aws_managed" {
  for_each = local.iam_role_policy_attachment_strings

  role       = split(local.iam_role_policy_attachments_delimiter, each.key)[0]
  policy_arn = data.aws_iam_policy.aws_managed[split(local.iam_role_policy_attachments_delimiter, each.key)[1]].arn

  # Yuck! If only Terraform were a tiny bit smarter with dependencies...
  depends_on = [
    aws_iam_role.hello_api_ecs_task_execution,
    aws_iam_role.hello_api_ecs_task
  ]
}
