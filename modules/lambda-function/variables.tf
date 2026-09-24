variable "function_name" {
  type = string
}

variable "handler" {
  type    = string
  default = "handler.handler"
}

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "source_zip_path" {
  type        = string
  description = "Path to a pre-built deployment zip (see lambda-src/build.sh)."
}

variable "timeout" {
  type    = number
  default = 30
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "sqs_trigger_arn" {
  type        = string
  description = "SQS queue ARN to subscribe this function to. Null disables the trigger."
  default     = null
}

variable "sqs_trigger_batch_size" {
  type    = number
  default = 1
}

variable "s3_trigger_bucket_id" {
  type        = string
  description = "S3 bucket to invoke this function on ObjectCreated. Null disables the trigger."
  default     = null
}

variable "s3_trigger_bucket_arn" {
  type    = string
  default = null
}

variable "iam_statements" {
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
  description = "Extra IAM permissions the function's role needs beyond its trigger wiring."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
