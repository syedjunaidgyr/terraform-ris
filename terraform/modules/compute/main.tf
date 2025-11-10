locals {
  name_prefix = "${var.project}-${var.environment}"
}

data "aws_ami" "al2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id
}

resource "aws_iam_role" "this" {
  name = "${local.name_prefix}-ec2-role"

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

  tags = merge(var.tags, { Name = "${local.name_prefix}-ec2-role" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.this.name
}

data "aws_region" "current" {}

locals {
  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    node_major_version = var.node_major_version
    pm2_version        = var.pm2_version
    app_user           = var.app_user
    app_directory      = var.app_directory
    project            = var.project
    environment        = var.environment
    app_port           = var.app_port
    region             = data.aws_region.current.name
  })
}

resource "aws_instance" "this" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.this.name

  user_data                   = local.user_data
  user_data_replace_on_change = true

  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-app" })
}

