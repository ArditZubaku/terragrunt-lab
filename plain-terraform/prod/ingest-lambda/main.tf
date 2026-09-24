terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "terragrunt-lab-plain-prod-tfstate"
    key    = "ingest-lambda/terraform.tfstate"
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

data "terraform_remote_state" "storage" {
  backend = "s3"

  config = {
    bucket = "terragrunt-lab-plain-prod-tfstate"
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

data "terraform_remote_state" "queue" {
  backend = "s3"

  config = {
    bucket = "terragrunt-lab-plain-prod-tfstate"
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

locals {
  function_name = "terragrunt-lab-plain-prod-ingest"
}

module "ingest_lambda" {
  source = "../../../modules/lambda-function"

  function_name   = local.function_name
  source_zip_path = "${path.module}/../../../build/ingest.zip"
  sqs_trigger_arn = data.terraform_remote_state.queue.outputs.queue_arn

  environment_variables = {
    REPORTS_BUCKET = data.terraform_remote_state.storage.outputs.bucket_id
  }

  iam_statements = [
    {
      sid       = "PutReports"
      actions   = ["s3:PutObject"]
      resources = ["${data.terraform_remote_state.storage.outputs.bucket_arn}/*"]
    }
  ]

  tags = {
    environment = "prod"
    managed_by  = "terraform"
  }
}
