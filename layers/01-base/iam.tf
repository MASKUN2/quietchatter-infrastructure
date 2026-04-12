# IAM Role for EC2 instances to use AWS Systems Manager (SSM)
resource "aws_iam_role" "ssm_role" {
  name = "quietchatter-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "quietchatter-ssm-role"
  }
}

# Attach the AmazonSSMManagedInstanceCore policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach inline policy to allow reading from Secrets Manager
resource "aws_iam_role_policy" "secrets_policy" {
  name = "quietchatter-secrets-policy"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.grafana_api_key.arn
        ]
      }
    ]
  })
}

# Create an Instance Profile to attach the role to EC2 instances
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "quietchatter-ssm-profile"
  role = aws_iam_role.ssm_role.name
}
