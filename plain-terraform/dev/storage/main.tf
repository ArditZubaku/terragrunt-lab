terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "terragrunt-lab-plain-dev-tfstate"
    key    = "storage/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "http://localhost:4566"
    }

    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
    use_path_style              = true
  }
}

provider "aws" {
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3             = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
  }
}

locals {
  bucket_name = "terragrunt-lab-plain-dev-reports"
}

module "reports_bucket" {
  source = "../../../modules/s3-bucket"

  bucket_name = local.bucket_name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

output "bucket_id" {
  value = module.reports_bucket.bucket_id
}

output "bucket_arn" {
  value = module.reports_bucket.bucket_arn
}
