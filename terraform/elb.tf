# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

resource "aws_lb" "hello_api" {
  name               = "hello-api"
  load_balancer_type = "application"

  internal        = false
  ip_address_type = "ipv4"
  subnets         = module.hello_api_vpc_subnets.public_subnet_ids

  security_groups = [
    aws_security_group.hello_api_load_balancer_from_source.id,
    aws_security_group.hello_api_load_balancer_to_target.id
  ]

  idle_timeout = 10 # seconds

  drop_invalid_header_fields                  = true
  enable_tls_version_and_cipher_suite_headers = true

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "hello_api" {
  name = "hello-api"

  vpc_id      = module.hello_api_vpc.vpc_id
  target_type = "ip"
  port        = 8000
  protocol    = "HTTP"

  health_check {
    enabled = true

    port     = 8000
    protocol = "HTTP"
    path     = "/healthcheck"

    timeout             = 5  # seconds
    interval            = 30 # seconds
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "hello_api_http_test" {
  load_balancer_arn = aws_lb.hello_api.arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_api.arn
  }
}
