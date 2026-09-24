locals {
  unit_dir   = get_original_terragrunt_dir()
  env_dir    = dirname(local.unit_dir)
  env_config = read_terragrunt_config("${local.env_dir}/env.hcl")
  env        = local.env_config.locals
}

dependency "storage" {
  config_path = "${local.env_dir}/storage"

  # Lets `plan`/`validate` run before storage has been applied.
  mock_outputs = {
    bucket_id  = "mock-bucket"
    bucket_arn = "arn:aws:s3:::mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "queue" {
  config_path = "${local.env_dir}/queue"

  mock_outputs = {
    queue_arn = "arn:aws:sqs:us-east-1:000000000000:mock-queue"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/modules//lambda-function"
}

inputs = {
  function_name   = "${local.env.name_prefix}-ingest"
  source_zip_path = "${get_repo_root()}/build/ingest.zip"
  sqs_trigger_arn = dependency.queue.outputs.queue_arn

  environment_variables = {
    REPORTS_BUCKET = dependency.storage.outputs.bucket_id
  }

  iam_statements = [
    {
      sid       = "PutReports"
      actions   = ["s3:PutObject"]
      resources = ["${dependency.storage.outputs.bucket_arn}/*"]
    }
  ]

  tags = {
    environment = local.env.environment
    managed_by  = "terragrunt"
  }
}
