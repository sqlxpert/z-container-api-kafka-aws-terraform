data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "hello_api_maintain_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
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
