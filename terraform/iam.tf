data "aws_caller_identity" "current" {}



data "aws_iam_policy_document" "hello_api_maintain_assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "hello_api_maintain" {
  name = "hello_api_maintain"

  assume_role_policy = data.aws_iam_policy_document.hello_api_maintain_assume_role.json
}
resource "aws_iam_instance_profile" "hello_api_maintain" {
  name = "hello_api_maintain"
  role = aws_iam_role.hello_api_maintain.name
}

data "aws_iam_policy" "iam_full_access" {
  name = "IAMFullAccess"
}
data "aws_iam_policy" "amazon_ssm_managed_instance_core" {
  name = "AmazonSSMManagedInstanceCore"
}
data "aws_iam_policy" "amazon_ec2_container_registry_full_access" {
  name = "AmazonEC2ContainerRegistryFullAccess"
}
data "aws_iam_policy" "cloud_watch_logs_full_access" {
  name = "CloudWatchLogsFullAccess"
}
data "aws_iam_policy" "amazon_ecs_full_access" {
  name = "AmazonECS_FullAccess"
}
data "aws_iam_policy" "amazon_msk_full_access" {
  name = "AmazonMSKFullAccess"
}


resource "aws_iam_role_policy_attachment" "hello_api_maintain_iam_full_access" {
  role       = aws_iam_role.hello_api_maintain.name
  policy_arn = data.aws_iam_policy.iam_full_access.arn
}
resource "aws_iam_role_policy_attachment" "hello_api_maintain_amazon_ssm_managed_instance_core" {
  role       = aws_iam_role.hello_api_maintain.name
  policy_arn = data.aws_iam_policy.amazon_ssm_managed_instance_core.arn
}
resource "aws_iam_role_policy_attachment" "hello_api_maintain_amazon_ec2_container_registry_full_access" {
  role       = aws_iam_role.hello_api_maintain.name
  policy_arn = data.aws_iam_policy.amazon_ec2_container_registry_full_access.arn
}
resource "aws_iam_role_policy_attachment" "hello_api_maintain_cloud_watch_logs_full_access" {
  role       = aws_iam_role.hello_api_maintain.name
  policy_arn = data.aws_iam_policy.cloud_watch_logs_full_access.arn
}
resource "aws_iam_role_policy_attachment" "hello_api_maintain_amazon_ecs_full_access" {
  role       = aws_iam_role.hello_api_maintain.name
  policy_arn = data.aws_iam_policy.amazon_ecs_full_access.arn
}
resource "aws_iam_role_policy_attachment" "hello_api_maintain_amazon_msk_full_access" {
  role       = aws_iam_role.hello_api_maintain.name
  policy_arn = data.aws_iam_policy.amazon_msk_full_access.arn
}



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
data "aws_iam_policy" "amazon_ecs_task_execution_role_policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "hello_api_ecs_task_execution_amazon_ecs_task_execution_role_policy" {
  role       = aws_iam_role.hello_api_ecs_task_execution.name
  policy_arn = data.aws_iam_policy.amazon_ecs_task_execution_role_policy.arn
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
      values   = ["arn:aws:ecs:${var.aws_region_main}:${data.aws_caller_identity.current.account_id}:*"]
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
resource "aws_iam_role_policy_attachment" "hello_api_ecs_task_amazon_msk_full_access" {
  role       = aws_iam_role.hello_api_ecs_task.name
  policy_arn = data.aws_iam_policy.amazon_msk_full_access.arn
}
