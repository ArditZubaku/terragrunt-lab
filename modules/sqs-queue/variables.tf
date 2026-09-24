variable "queue_name" {
  type        = string
  description = "SQS queue name."
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "Must be >= the timeout of any Lambda consuming this queue."
  default     = 60
}

variable "message_retention_seconds" {
  type    = number
  default = 86400
}

variable "receive_wait_time_seconds" {
  type    = number
  default = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
