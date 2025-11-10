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

