# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

resource "aws_cloudwatch_log_group" "hello_api_ecs_cluster" {
  name         = "hello_api_ecs_cluster"
  skip_destroy = true

  log_group_class   = "STANDARD"
  retention_in_days = 3
}

resource "aws_ecs_cluster" "hello_api" {
  name = "hello_api"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.hello_api_ecs_cluster.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "hello_api" {
  cluster_name = aws_ecs_cluster.hello_api.name

  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }
}

resource "aws_ecs_task_definition" "hello_api" {
  family = "hello_api"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512  # "CPU units"; 512 CPU units = 0.5 vCPU
  memory                   = 1024 # GiB
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  execution_role_arn = aws_iam_role.hello_api_ecs_task_execution.arn
  task_role_arn      = aws_iam_role.hello_api_ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "hello_api"
      image = "${aws_ecr_repository.hello_api.repository_url}:${var.hello_api_aws_ecr_image_tag}"

      privileged = false

      essential    = true
      startTimeout = 090 # seconds
      stopTimeout  = 060 # seconds

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl --fail --silent --show-error 'http://127.0.0.1:8000/healthcheck' || exit 1"
        ]

        startPeriod = 060 # seconds
        timeout     = 005 # seconds
        retries     = 3
        interval    = 005 # seconds
      }

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "hello_api" {
  name = "hello_api"

  cluster = aws_ecs_cluster.hello_api.id

  task_definition = aws_ecs_task_definition.hello_api.arn

  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  desired_count    = var.hello_api_aws_ecs_service_desired_count_tasks
  propagate_tags   = "NONE"

  availability_zone_rebalancing = "ENABLED"
  network_configuration {
    subnets = [
      for data_aws_subnet in data.aws_subnet.private_list : data_aws_subnet.id
    ]
    security_groups = [
      data.aws_security_group.hello_api_load_balancer_target.id
    ]
    assign_public_ip = true # TODO: remove
    # assign_public_ip = false
  }
}
