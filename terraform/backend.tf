terraform {
  backend "s3" {
    bucket       = "ris-terraform-state"
    key          = "terraform-ris/infra.tfstate"
    region       = "ap-south-1"
    profile      = "default" # or remove if you’ll set AWS_PROFILE
    encrypt      = true
    use_lockfile = true # replaces the old dynamodb_table setting
  }
}