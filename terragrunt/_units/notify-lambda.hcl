locals {
  unit_dir   = get_original_terragrunt_dir()
  env_dir    = dirname(local.unit_dir)
  env_config = read_terragrunt_config("${local.env_dir}/env.hcl")
  env        = local.env_config.locals
}

dependency "storage" {
  config_path = "${local.env_dir}/storage"

  mock_outputs = {
    bucket_id  = "mock-bucket"
    bucket_arn = "arn:aws:s3:::mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/modules//lambda-function"
}

inputs = {
  function_name         = "${local.env.name_prefix}-notify"
  source_zip_path       = "${get_repo_root()}/build/notify.zip"
  s3_trigger_bucket_id  = dependency.storage.outputs.bucket_id
  s3_trigger_bucket_arn = dependency.storage.outputs.bucket_arn

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
  }
}
