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
  custom_policies = {

    "kafka_write" = {
      description     = "MSK hello_api cluster: create, write to '${var.kafka_topic}' topic"
      policy_document = data.aws_iam_policy_document.kafka_write
    }
  }

  roles = {

    "hello_api_ecs_task_execution" = {
      assume_role_policy_document = data.aws_iam_policy_document.hello_api_ecs_task_execution_assume_role
      attach_policies = [
        "AmazonECSTaskExecutionRolePolicy",
      ]
    }

    "hello_api_ecs_task" = {
      assume_role_policy_document = data.aws_iam_policy_document.hello_api_ecs_task_assume_role
      attach_policies = [
        "kafka_write",
      ]
    }
  }

  create_custom_policies = {
    for policy_name, policy_detail in local.custom_policies :
    policy_name => merge(
      policy_detail,
      { policy_document = one(policy_detail["policy_document"][*]) },
    )
    if length(policy_detail["policy_document"][*]) == 1
    # https://developer.hashicorp.com/terraform/language/expressions/splat#single-values-as-lists
    # Accept a static (type: object) or conditionally created (count = 1,
    # producing type: list of objects) data.aws_iam_policy_document .
  }

  do_not_create_custom_policies_set = setsubtract(
    toset(keys(local.custom_policies)),
    toset(keys(local.create_custom_policies))
  )

  attach_role_policies_set = setsubtract(
    toset(flatten(values(local.roles)[*]["attach_policies"])),
    local.do_not_create_custom_policies_set
  )

  role_policy_attachments = flatten([
    for role_name, role_detail in local.roles :
    [
      for policy_name in role_detail["attach_policies"] :
      {
        "role_name"   = role_name
        "policy_name" = policy_name
      }
      if contains(local.attach_role_policies_set, policy_name)
    ]
  ])

  role_policy_attachments_map = {
    for attach in local.role_policy_attachments :
    join(":", [attach["role_name"], attach["policy_name"]]) => attach
  }
}

resource "aws_iam_policy" "hello_custom" {
  for_each = local.create_custom_policies

  name        = each.key
  description = each.value["description"]

  policy = each.value["policy_document"].json
}

data "aws_iam_policy" "hello_attach" {
  for_each = local.attach_role_policies_set

  name = each.key

  depends_on = [aws_iam_policy.hello_custom] # Indirectly by name, for these!
}

resource "aws_iam_role" "hello" {
  for_each = local.roles

  name = each.key

  assume_role_policy = each.value["assume_role_policy_document"].json
}

resource "aws_iam_role_policy_attachment" "hello" {
  for_each = local.role_policy_attachments_map

  role       = each.value["role_name"]
  policy_arn = data.aws_iam_policy.hello_attach[each.value["policy_name"]].arn

  depends_on = [aws_iam_role.hello]
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
