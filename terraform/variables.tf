variable "aws_region_main" {
  type        = string
  description = "Main region code for AWS provider. You can override this in individual resource definitions as of v6.0.0 (2025-06-18). See https://registry.terraform.io/providers/hashicorp/aws/6.0.0/docs/guides/enhanced-region-support#whats-new"

  default = "us-west-2"
}
