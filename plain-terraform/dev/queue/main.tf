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
    key    = "queue/terraform.tfstate"
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
  queue_name = "terragrunt-lab-plain-dev-ingest"
}

module "ingest_queue" {
  source = "../../../modules/sqs-queue"

  queue_name = local.queue_name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

output "queue_id" {
  value = module.ingest_queue.queue_id
}

output "queue_arn" {
  value = module.ingest_queue.queue_arn
}

output "queue_name" {
  value = module.ingest_queue.queue_name
}
