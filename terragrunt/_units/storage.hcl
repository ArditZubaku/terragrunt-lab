locals {
  unit_dir   = get_original_terragrunt_dir()
  env_dir    = dirname(local.unit_dir)
  env_config = read_terragrunt_config("${local.env_dir}/env.hcl")
  env        = local.env_config.locals
}

terraform {
  source = "${get_repo_root()}/modules//s3-bucket"
}

inputs = {
  bucket_name = "${local.env.name_prefix}-reports"

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
  }
}
