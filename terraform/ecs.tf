# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

# For future use; see below
resource "aws_cloudwatch_log_group" "hello_api_ecs_cluster" {
  name = "hello_api_ecs_cluster"

  log_group_class   = "STANDARD"
  retention_in_days = 3
}

# Pre-create to be sure this is tracked
resource "aws_cloudwatch_log_group" "hello_api_ecs_task" {
  name = "hello_api_ecs_task"

  log_group_class   = "STANDARD"
  retention_in_days = 3
}

resource "aws_ecs_cluster" "hello_api" {
  name = "hello_api"

  # For future use, if it's necessary to run arbitrary commands in containers.
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
  #
  # configuration {
  #   execute_command_configuration {
  #     logging = "OVERRIDE"
  #     log_configuration {
  #       cloud_watch_encryption_enabled = true
  #       cloud_watch_log_group_name     = aws_cloudwatch_log_group.hello_api_ecs_cluster.name
  #     }
  #   }
  # }
}

resource "aws_ecs_cluster_capacity_providers" "hello_api" {
  cluster_name = aws_ecs_cluster.hello_api.name

  capacity_providers = [
    "FARGATE_SPOT",
    "FARGATE"
  ]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0 # All spot, for a low-cost demonstration!
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
          "curl --fail --silent --show-error 'http://127.0.0.1:${local.tcp_ports["hello_api"]}/healthcheck' || exit 1"
        ]

        startPeriod = 060 # seconds
        timeout     = 005 # seconds
        retries     = 3
        interval    = 005 # seconds
      }

      environment = [
        {
          name = "HELLO_API_AWS_MSK_CLUSTER_BOOTSTRAP"
          value = try(
            aws_msk_serverless_cluster.hello_api[0].bootstrap_brokers_sasl_iam,
            ""
          )
        },
        {
          name  = "HELLO_API_AWS_MSK_CLUSTER_TOPIC"
          value = var.kafka_topic
        }
        # See also
        # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-environment-variables.html
      ]

      portMappings = [
        {
          protocol      = "tcp"
          containerPort = local.tcp_ports["hello_api"]
          hostPort      = local.tcp_ports["hello_api"]
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region = local.aws_region_main

          awslogs-create-group  = "true" # String (!), and "false" not allowed
          awslogs-group         = aws_cloudwatch_log_group.hello_api_ecs_task.name
          awslogs-stream-prefix = "awslogs-stream-prefix"

          mode            = "non-blocking"
          max-buffer-size = "10m"
        }
      }
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
    subnets          = module.hello_api_vpc_subnets.private_subnet_ids
    assign_public_ip = false

    security_groups = [
      aws_security_group.hello_api_load_balancer_target.id,
      aws_security_group.hello_api_kafka_client.id,
      aws_security_group.hello_api_vpc_all_egress.id
      # Could narrow egress to VPC interface endpoints only, in the future
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hello_api.arn
    container_name   = "hello_api"
    container_port   = local.tcp_ports["hello_api"]
  }
}
