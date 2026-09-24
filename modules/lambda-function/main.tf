data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

locals {
  log_statements = [{
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }]

  sqs_statements = var.sqs_trigger_arn == null ? [] : [{
    sid       = "ConsumeTriggerQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [var.sqs_trigger_arn]
  }]

  all_statements = concat(local.log_statements, local.sqs_statements, var.iam_statements)
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = local.all_statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.this.arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  filename         = var.source_zip_path
  source_code_hash = filebase64sha256(var.source_zip_path)
  tags             = var.tags

  environment {
    variables = var.environment_variables
  }
}

resource "aws_lambda_event_source_mapping" "sqs" {
  count = var.sqs_trigger_arn == null ? 0 : 1

  event_source_arn = var.sqs_trigger_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = var.sqs_trigger_batch_size
}

resource "aws_lambda_permission" "s3" {
  count = var.s3_trigger_bucket_arn == null ? 0 : 1

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_trigger_bucket_arn
}

# aws_s3_bucket_notification replaces the bucket's whole notification config,
# so it must live in the consumer (this module), never in the s3-bucket module,
# or two consumers of the same bucket would fight over ownership.
resource "aws_s3_bucket_notification" "this" {
  count = var.s3_trigger_bucket_id == null ? 0 : 1

  bucket = var.s3_trigger_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3]
}
