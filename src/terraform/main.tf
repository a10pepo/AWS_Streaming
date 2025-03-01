terraform {
  backend "s3" {
    bucket = "pnieto-terraform-state"
    key    = "terraform/state"
    region = "eu-central-1"  # Change to your desired AWS region
  }
}

module "api_repository" {
  source = "./api"  
}

module "api_messaging" {
  source = "./messaging"
}

module "rds" {
  source = "./rds"
}