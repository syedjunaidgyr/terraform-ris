locals {
  name_prefix = "${var.project}-${var.environment}"

  default_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "terraform-ris"
  }

  tags = merge(local.default_tags, var.extra_tags)

  db_seed_file_list = (
    length(var.db_seed_sql_files) > 0
    ? var.db_seed_sql_files
    : (
      var.db_seed_sql_file != ""
      ? [var.db_seed_sql_file]
      : []
    )
  )

  db_seed_file_paths = [for file in local.db_seed_file_list : abspath(file)]
}

