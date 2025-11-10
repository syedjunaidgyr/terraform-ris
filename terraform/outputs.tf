output "vpc_id" {
  description = "ID of the provisioned VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "app_instance_id" {
  description = "ID of the application EC2 instance."
  value       = module.app.instance_id
}

output "app_instance_public_ip" {
  description = "Public IPv4 address of the application EC2 instance."
  value       = module.app.public_ip
}

output "app_instance_public_dns" {
  description = "Public DNS name of the application EC2 instance."
  value       = module.app.public_dns
}

output "database_endpoint" {
  description = "Endpoint address of the MySQL database."
  value       = module.database.endpoint
}

output "database_port" {
  description = "Port of the MySQL database."
  value       = module.database.port
}

output "database_name" {
  description = "Name of the provisioned database schema."
  value       = module.database.db_name
}

output "database_username" {
  description = "Master username for the database."
  value       = module.database.db_username
}

