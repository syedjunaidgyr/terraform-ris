variable "project" {
  description = "Project name used for tagging and resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod)."
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources into."
  type        = string
}

variable "aws_profile" {
  description = "Optional named AWS CLI profile to use."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to spread public subnets across."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type for the application server."
  type        = string
  default     = "t3.medium"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks permitted to SSH into the instance."
  type        = list(string)
  default     = []
}

variable "app_port" {
  description = "Application port to expose through the security group."
  type        = number
  default     = 3000
}

variable "root_volume_size" {
  description = "Size (in GB) of the EC2 root volume."
  type        = number
  default     = 30
}

variable "node_major_version" {
  description = "Major Node.js version to install via NodeSource."
  type        = string
  default     = "18"
}

variable "pm2_version" {
  description = "Version constraint for the global pm2 installation."
  type        = string
  default     = "latest"
}

variable "app_user" {
  description = "Linux user that owns and runs the Node.js application."
  type        = string
  default     = "ris"
}

variable "app_directory" {
  description = "Filesystem path that will host the deployed application."
  type        = string
  default     = "/opt/ris/current"
}

variable "frontend_port" {
  description = "Port the RIS frontend Next.js application should listen on."
  type        = number
  default     = 3002
}

variable "pacs_service_port" {
  description = "Port reserved for PACS-related services exposed on the host."
  type        = number
  default     = 3001
}

variable "template_service_port" {
  description = "Port used by the RIS template backend service."
  type        = number
  default     = 6011
}

variable "ai_service_port" {
  description = "Port used by the AI image analysis service."
  type        = number
  default     = 8000
}

variable "repo_ris_backend" {
  description = "Git repository URL for the RIS backend."
  type        = string
  default     = "https://github.com/zaenAbdulali/ris-backend.git"
}

variable "repo_ris_frontend" {
  description = "Git repository URL for the RIS frontend."
  type        = string
  default     = "https://github.com/zaenAbdulali/ris-frontend.git"
}

variable "repo_pacs_frontend" {
  description = "Git repository URL for the PACS frontend."
  type        = string
  default     = "https://github.com/shanmukhaPriyagyr/pacs_frontend.git"
}

variable "repo_ris_template" {
  description = "Git repository URL for the RIS template backend."
  type        = string
  default     = "https://github.com/Niyam23/RIS-Backend-Template.git"
}

variable "repo_openai_image_analysis" {
  description = "Git repository URL for the OpenAI image analysis service."
  type        = string
  default     = "https://github.com/zaenAbdulali/openai-image-analysis.git"
}

variable "repo_orthanc" {
  description = "Git repository URL for Orthanc tooling."
  type        = string
  default     = "https://github.com/zaenAbdulali/orthanc.git"
}

variable "github_username" {
  description = "Username associated with the GitHub personal access token used for cloning private repositories."
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token used for cloning private repositories."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ris_jwt_secret" {
  description = "JWT secret used by the RIS backend service."
  type        = string
  default     = "change-me"
  sensitive   = true
}

variable "openai_api_key" {
  description = "API key for the OpenAI image analysis service."
  type        = string
  default     = ""
  sensitive   = true
}

variable "extra_tags" {
  description = "Optional additional tags to merge onto every resource."
  type        = map(string)
  default     = {}
}

variable "db_name" {
  description = "Name of the initial MySQL database to create."
  type        = string
  default     = "ris"
}

variable "db_username" {
  description = "Master username for the MySQL database."
  type        = string
  default     = "ris_admin"
}

variable "db_password" {
  description = "Master password for the MySQL database."
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port on which the MySQL instance listens."
  type        = number
  default     = 3306
}

variable "db_instance_class" {
  description = "Instance class/size for the RDS MySQL instance."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage (in GB) for the MySQL instance."
  type        = number
  default     = 50
}

variable "db_max_allocated_storage" {
  description = "Maximum storage (in GB) that the instance can automatically scale to. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Whether to create the database in a Multi-AZ configuration."
  type        = bool
  default     = false
}

variable "db_publicly_accessible" {
  description = "Whether the database should be publicly accessible."
  type        = bool
  default     = false
}

variable "db_storage_encrypted" {
  description = "Whether to enable storage encryption on the database."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip taking a final snapshot when destroying the database."
  type        = bool
  default     = true
}

variable "db_apply_immediately" {
  description = "Whether modifications are applied immediately or during the next maintenance window."
  type        = bool
  default     = false
}

variable "db_seed_enabled" {
  description = "Enable Terraform-driven database seeding using the provided SQL file (requires mysql client)."
  type        = bool
  default     = false
}

variable "db_seed_sql_file" {
  description = "DEPRECATED: use db_seed_sql_files instead. Kept for backward compatibility with single-file seeding."
  type        = string
  default     = ""
}

variable "db_seed_sql_files" {
  description = "List of SQL files to apply (in order) when db_seed_enabled is true."
  type        = list(string)
  default     = []
}

variable "db_engine_version" {
  description = "Version of the MySQL engine."
  type        = string
  default     = ""
}

