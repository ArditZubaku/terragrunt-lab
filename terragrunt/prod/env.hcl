locals {
  environment      = "prod"
  state_bucket     = "terragrunt-lab-tg-prod-tfstate"
  aws_region       = "us-east-1"
  aws_endpoint_url = "http://localhost:4566"
  name_prefix      = "terragrunt-lab-tg-prod"
}
