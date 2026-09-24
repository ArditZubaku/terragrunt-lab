locals {
  environment      = "dev"
  state_bucket     = "terragrunt-lab-tg-dev-tfstate"
  aws_region       = "us-east-1"
  aws_endpoint_url = "http://localhost:4566"
  name_prefix      = "terragrunt-lab-tg-dev"
}
