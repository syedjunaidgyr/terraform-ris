variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type = string
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

variable "db_port" {
  type = number
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  type = number
}

variable "backup_retention_period" {
  type = number
}

variable "multi_az" {
  type = bool
}

variable "publicly_accessible" {
  type = bool
}

variable "storage_encrypted" {
  type = bool
}

variable "skip_final_snapshot" {
  type = bool
}

variable "apply_immediately" {
  type = bool
}

variable "engine_version" {
  type    = string
  default = ""
}

variable "tags" {
  type = map(string)
}

variable "seed_enabled" {
  type = bool
}

variable "seed_sql_file" {
  type    = string
  default = ""
}

variable "seed_sql_files" {
  type    = list(string)
  default = []
}

