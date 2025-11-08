# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

# Possible future use for ECS Exec
resource "aws_cloudwatch_log_group" "hello_api_ecs_cluster" {
  region = local.aws_region_main
  name   = "hello_api_ecs_cluster"

  log_group_class   = "STANDARD"
  retention_in_days = 3
}

# Pre-create to be sure this is tracked
resource "aws_cloudwatch_log_group" "hello_api_ecs_task" {
  region = local.aws_region_main
  name   = "hello_api_ecs_task"

  log_group_class   = "STANDARD"
  retention_in_days = 3
}

resource "aws_ecs_cluster" "hello_api" {
  region = local.aws_region_main
  name   = "hello_api"

  configuration {

    # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html#ecs-exec-enabling-logging
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "hello_api" {
  region       = local.aws_region_main
  cluster_name = aws_ecs_cluster.hello_api.name

  capacity_providers = [
    "FARGATE_SPOT",
    "FARGATE",
  ]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0 # All spot (adjust for always-on certainty)
  }
}

resource "aws_ecs_task_definition" "hello_api" {
  region = local.aws_region_main
  family = "hello_api"

  lifecycle {
    create_before_destroy = true # When var.enable_kafka changes
  }

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512  # "CPU units"; 512 CPU units = 0.5 vCPU
  memory                   = 1024 # GiB
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  execution_role_arn = aws_iam_role.hello["hello_api_ecs_task_execution"].arn
  task_role_arn      = aws_iam_role.hello["hello_api_ecs_task"].arn

  container_definitions = jsonencode([
    {
      name  = "hello_api"
      image = "${aws_ecr_repository.hello.repository_url}:${var.hello_api_aws_ecr_image_tag}"

      privileged = false

      essential    = true
      startTimeout = 090 # seconds
      stopTimeout  = 060 # seconds

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl --fail --silent --show-error 'http://127.0.0.1:${local.tcp_ports["hello_api_private"]}/healthcheck' || exit 1"
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
          containerPort = local.tcp_ports["hello_api_private"]
          hostPort      = local.tcp_ports["hello_api_private"]
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region = local.aws_region_main

          awslogs-create-group  = "true" # String (!), and "false" not allowed
          awslogs-group         = aws_cloudwatch_log_group.hello_api_ecs_task.name
          awslogs-stream-prefix = "hello_api"

          mode            = "non-blocking"
          max-buffer-size = "10m"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "hello_api" {
  region  = local.aws_region_main
  cluster = aws_ecs_cluster.hello_api.id
  name    = "hello_api"

  task_definition        = aws_ecs_task_definition.hello_api.arn
  enable_execute_command = var.enable_ecs_exec

  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  desired_count    = var.hello_api_aws_ecs_service_desired_count_tasks
  propagate_tags   = "NONE"

  availability_zone_rebalancing = "ENABLED"
  network_configuration {
    subnets          = module.hello_vpc_subnets.private_subnet_ids
    assign_public_ip = false

    security_groups = [
      aws_security_group.hello["ecs_task"].id,
      aws_security_group.hello["hello_api_private"].id,
      aws_security_group.hello["kafka_client"].id,
    ]
  }

  dynamic "load_balancer" {
    for_each = aws_lb_target_group.hello_api

    content {
      container_name = jsondecode(
        aws_ecs_task_definition.hello_api.container_definitions
      )[0].name
      container_port = load_balancer.value.port

      target_group_arn = load_balancer.value.arn
    }
  }
}
