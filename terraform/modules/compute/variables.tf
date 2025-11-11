variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

variable "root_volume_size" {
  type    = number
  default = 30
}

variable "app_directory" {
  type = string
}

variable "app_user" {
  type = string
}

variable "node_major_version" {
  type = string
}

variable "pm2_version" {
  type = string
}

variable "app_port" {
  type = number
}

variable "ami_id" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "frontend_port" {
  type = number
}

variable "pacs_service_port" {
  type = number
}

variable "template_service_port" {
  type = number
}

variable "ai_service_port" {
  type = number
}

variable "repo_ris_backend" {
  type = string
}

variable "repo_ris_frontend" {
  type = string
}

variable "repo_pacs_frontend" {
  type = string
}

variable "repo_ris_template" {
  type = string
}

variable "repo_openai_image_analysis" {
  type = string
}

variable "repo_orthanc" {
  type = string
}

variable "github_username" {
  type    = string
  default = ""
}

variable "github_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ris_jwt_secret" {
  type = string
}

variable "openai_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

