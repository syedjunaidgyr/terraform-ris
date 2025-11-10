module "network" {
  source = "./modules/network"

  project             = var.project
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
  tags                = local.tags
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Allow web and SSH traffic to the application host"
  vpc_id      = module.network.vpc_id

  dynamic "ingress" {
    for_each = toset(var.allowed_ssh_cidrs)

    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend application port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend application port"
    from_port   = var.frontend_port
    to_port     = var.frontend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PACS service port"
    from_port   = var.pacs_service_port
    to_port     = var.pacs_service_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Template service port"
    from_port   = var.template_service_port
    to_port     = var.template_service_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "AI service port"
    from_port   = var.ai_service_port
    to_port     = var.ai_service_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RIS auxiliary services"
    from_port   = 6000
    to_port     = 6009
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PACS / AI services"
    from_port   = 9000
    to_port     = 9005
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-app-sg" })
}

module "app" {
  source = "./modules/compute"

  project            = var.project
  environment        = var.environment
  subnet_id          = module.network.public_subnet_ids[0]
  security_group_ids = [aws_security_group.app.id]
  instance_type      = var.instance_type
  ssh_key_name       = var.ssh_key_name
  root_volume_size   = var.root_volume_size

  app_directory         = var.app_directory
  app_user              = var.app_user
  node_major_version    = var.node_major_version
  pm2_version           = var.pm2_version
  app_port              = var.app_port
  frontend_port         = var.frontend_port
  pacs_service_port     = var.pacs_service_port
  template_service_port = var.template_service_port
  ai_service_port       = var.ai_service_port

  db_host     = module.database.endpoint
  db_port     = var.db_port
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  repo_ris_backend           = var.repo_ris_backend
  repo_ris_frontend          = var.repo_ris_frontend
  repo_pacs_frontend         = var.repo_pacs_frontend
  repo_ris_template          = var.repo_ris_template
  repo_openai_image_analysis = var.repo_openai_image_analysis
  repo_orthanc               = var.repo_orthanc
  ris_jwt_secret             = var.ris_jwt_secret
  openai_api_key             = var.openai_api_key

  tags = local.tags
}

module "database" {
  source = "./modules/database"

  project               = var.project
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.public_subnet_ids
  app_security_group_id = aws_security_group.app.id

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  db_port     = var.db_port

  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  backup_retention_period = var.db_backup_retention_period
  multi_az                = var.db_multi_az
  publicly_accessible     = var.db_publicly_accessible
  storage_encrypted       = var.db_storage_encrypted
  skip_final_snapshot     = var.db_skip_final_snapshot
  apply_immediately       = var.db_apply_immediately
  engine_version          = var.db_engine_version

  seed_enabled   = var.db_seed_enabled
  seed_sql_files = local.db_seed_file_paths

  tags = local.tags
}

