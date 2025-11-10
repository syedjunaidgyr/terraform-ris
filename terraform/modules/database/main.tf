locals {
  name_prefix = "${var.project}-${var.environment}"
  seed_file_list = (
    length(var.seed_sql_files) > 0
    ? var.seed_sql_files
    : (
      var.seed_sql_file != ""
      ? [var.seed_sql_file]
      : []
    )
  )
  seed_sql_map = {
    for idx, file_path in local.seed_file_list :
    idx => abspath(file_path)
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Allow database traffic from application hosts"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from app security group"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    security_groups = [
      var.app_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-db-sg" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${local.name_prefix}-db-subnets" })
}

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-mysql"

  engine                = "mysql"
  engine_version        = var.engine_version != "" ? var.engine_version : null
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  multi_az                   = var.multi_az
  publicly_accessible        = var.publicly_accessible
  backup_retention_period    = var.backup_retention_period
  deletion_protection        = false
  skip_final_snapshot        = var.skip_final_snapshot
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = true
  monitoring_interval        = 0

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = merge(var.tags, { Name = "${local.name_prefix}-mysql" })
}

resource "null_resource" "seed_database" {
  for_each = var.seed_enabled ? local.seed_sql_map : {}

  triggers = {
    db_instance_id    = aws_db_instance.this.id
    seed_sql_checksum = filemd5(each.value)
    seed_sql_path     = each.value
    db_endpoint       = aws_db_instance.this.address
    order_index       = each.key
  }

  provisioner "local-exec" {
    when        = create
    command     = <<-EOT
      set -euo pipefail
      if ! command -v mysql >/dev/null 2>&1; then
        echo "mysql client not found on local machine; required when db_seed_enabled=true."
        exit 1
      fi
      MYSQL_PWD='${replace(var.db_password, "'", "'\"'\"'")}' mysql \
        --host='${aws_db_instance.this.address}' \
        --port='${var.db_port}' \
        --user='${var.db_username}' \
        --default-character-set=utf8mb4 \
        ${var.db_name} < '${each.value}'
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

