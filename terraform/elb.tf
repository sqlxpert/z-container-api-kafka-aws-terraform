# Container Python API, Kafka, Lambda consumer, via Terraform + CloudFormation
# github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws
# GPLv3, Copyright Paul Marcelin

resource "aws_lb" "hello_api" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  region             = local.aws_region_main
  name               = "hello-api"
  load_balancer_type = "application"

  internal        = false
  ip_address_type = "ipv4"
  subnets         = module.hello_vpc_subnets.public_subnet_ids

  security_groups = [
    aws_security_group.hello["hello_api_public"].id,
    aws_security_group.hello["hello_api_private_client"].id
  ]

  idle_timeout = 10 # seconds

  drop_invalid_header_fields                  = true
  enable_tls_version_and_cipher_suite_headers = true

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "hello_api" {
  count = var.create_vpc_endpoints_and_load_balancer ? 1 : 0

  region = local.aws_region_main
  name   = "hello-api"

  vpc_id      = module.hello_vpc.vpc_id
  target_type = "ip"
  port        = local.tcp_ports["hello_api_private"]
  protocol    = "HTTP"

  health_check {
    enabled = true

    port     = local.tcp_ports["hello_api_private"]
    protocol = "HTTP"
    path     = "/healthcheck"

    timeout             = 5  # seconds
    interval            = 30 # seconds
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# A single listener for the non-encrypted port, with variable default_action
# content, avoids a Terraform error and the need for a double-apply when
# toggling enable_https . As of 2025-09, Terraform has no
# create-after-destroy-like feature that would allow a forward listener to be
# destroyed before a redirect listener is created on the same port.
# Error: creating ELBv2 Listener ([arn]): operation error Elastic Load
# Balancing v2: CreateListener, https response error StatusCode: 400,
# RequestID: [...], DuplicateListener: A listener already exists on this port
# for this load balancer '[arn]'
# Feature request punted to the provider:
# https://github.com/hashicorp/terraform/issues/26407

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

locals {
  protocol_redirect = merge(

    var.create_vpc_endpoints_and_load_balancer ? {
      http = false
    } : {},

    (var.create_vpc_endpoints_and_load_balancer && var.enable_https) ? {
      https = false
      http  = true
    } : {},
  )
}

resource "aws_lb_listener" "hello_api" {
  for_each = local.protocol_redirect

  region            = local.aws_region_main
  load_balancer_arn = aws_lb.hello_api[0].arn

  protocol = upper(each.key)
  port     = tostring(local.tcp_ports[each.key])

  ssl_policy      = each.key == "https" ? "ELBSecurityPolicy-TLS13-1-2-Res-2021-06" : null
  certificate_arn = each.key == "https" ? module.hello_api_tls_certificate.certificate_arn : null

  default_action {
    type = each.value ? "redirect" : "forward"

    target_group_arn = each.value ? null : aws_lb_target_group.hello_api[0].arn

    dynamic "redirect" {
      for_each = toset(each.value ? ["https"] : [])

      content {
        protocol = upper(redirect.key)
        port     = tostring(local.tcp_ports[redirect.key])

        status_code = "HTTP_301"
      }
    }
  }
}
