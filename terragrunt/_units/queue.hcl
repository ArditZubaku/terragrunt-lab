locals {
  unit_dir   = get_original_terragrunt_dir()
  env_dir    = dirname(local.unit_dir)
  env_config = read_terragrunt_config("${local.env_dir}/env.hcl")
  env        = local.env_config.locals
}

terraform {
  source = "${get_repo_root()}/modules//sqs-queue"
}

inputs = {
  queue_name = "${local.env.name_prefix}-ingest"

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
  }
}
