locals {
  env_config = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env        = local.env_config.locals
  unit       = basename(get_terragrunt_dir())
}

generate "provider" {
  path      = "provider.generated.tf"
  if_exists = "overwrite_terragrunt"

  # No `required_providers` here: terraform.source always points at one of
  # our modules, and each already declares its own (versions.tf). Terraform
  # errors on two required_providers blocks for the same provider in one
  # module, which is exactly what generating a second one here would cause.
  contents = <<-EOF
    provider "aws" {
      region = "${local.env.aws_region}"

      access_key                  = "test"
      secret_key                  = "test"
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_requesting_account_id  = true
      s3_use_path_style           = true

      endpoints {
        s3             = "${local.env.aws_endpoint_url}"
        sqs            = "${local.env.aws_endpoint_url}"
        lambda         = "${local.env.aws_endpoint_url}"
        iam            = "${local.env.aws_endpoint_url}"
        sts            = "${local.env.aws_endpoint_url}"
        cloudwatchlogs = "${local.env.aws_endpoint_url}"
      }
    }
  EOF
}

# Every unit gets its own state file, keyed by unit name, inside the
# per-environment bucket from env.hcl. Pass --backend-bootstrap (see
# Makefile) and Terragrunt creates that bucket itself -- plain Terraform has
# no equivalent, see Makefile's plain-bootstrap-* targets.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.generated.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = local.env.state_bucket
    key    = "${local.unit}/terraform.tfstate"
    region = local.env.aws_region

    endpoints = {
      s3 = local.env.aws_endpoint_url
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
