# Containerized REST API, Kafka, Lambda consumer, via Terraform (demo)
# github.com/sqlxpert/z-container-api-kafka-aws-terraform
# GPLv3, Copyright Paul Marcelin

resource "aws_lb" "hello_api" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  name               = "hello-api"
  load_balancer_type = "application"

  internal        = false
  ip_address_type = "ipv4"
  subnets         = module.hello_api_vpc_subnets.public_subnet_ids

  security_groups = [
    aws_security_group.hello_api_load_balancer_outside.id,
    aws_security_group.hello_api_load_balancer_inside.id
  ]

  idle_timeout = 10 # seconds

  drop_invalid_header_fields                  = true
  enable_tls_version_and_cipher_suite_headers = true

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "hello_api" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  name = "hello-api"

  vpc_id      = module.hello_api_vpc.vpc_id
  target_type = "ip"
  port        = local.tcp_ports["hello_api"]
  protocol    = "HTTP"

  health_check {
    enabled = true

    port     = local.tcp_ports["hello_api"]
    protocol = "HTTP"
    path     = "/healthcheck"

    timeout             = 5  # seconds
    interval            = 30 # seconds
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# As of 2025-09, Terraform has no create-after-destroy-like feature that would
# allow a forward listener on Port 80 to be destroyed before a redirect
# listener is created on the same port. Just apply twice! The error was:
# Error: creating ELBv2 Listener ([arn]): operation error Elastic Load
# Balancing v2: CreateListener, https response error StatusCode: 400,
# RequestID: [...], DuplicateListener: A listener already exists on this port
# for this load balancer '[arn]'
# Feature request punted to the provider:
# https://github.com/hashicorp/terraform/issues/26407

resource "aws_lb_listener" "hello_api_http_only" {
  count = (
    var.create_vpc_endpoints_and_load_balancer && !var.enable_https ? 1 : 0
  )

  load_balancer_arn = aws_lb.hello_api[0].arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_api[0].arn
  }
}

module "hello_api_tls_certificate" {
  source  = "cloudposse/ssm-tls-self-signed-cert/aws"
  version = "1.3.0"

  enabled = var.enable_https

  certificate_backends = ["ACM"]
  certificate_chain = {
    cert_pem        = ""
    private_key_pem = ""
  }

  subject = {
    common_name         = "hello-api.example.com"
    organization        = "None"
    organizational_unit = "None"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "aws_lb_listener" "hello_api_http_redirect_to_https" {
  count = (
    var.create_vpc_endpoints_and_load_balancer && var.enable_https ? 1 : 0
  )

  load_balancer_arn = aws_lb.hello_api[0].arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "hello_api_https" {
  count = (
    var.create_vpc_endpoints_and_load_balancer && var.enable_https ? 1 : 0
  )

  load_balancer_arn = aws_lb.hello_api[0].arn

  port            = "443"
  protocol        = "HTTPS"
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn = module.hello_api_tls_certificate.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_api[0].arn
  }
}
