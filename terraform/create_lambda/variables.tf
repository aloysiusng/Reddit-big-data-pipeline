# Required variables ================================================================
variable "lambda_function_name" {
  type = string
}

variable "lambda_file_name" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "lambda_handler" {
  type = string
}

variable "lambda_runtime" {
  type = string
}
# Default variables ================================================================
variable "lambda_timeout" {
  type    = number
  default = 900
}

variable "lambda_layers_arn" {
  type    = list(string)
  default = []
}

variable "lambda_memory_size" {
  type        = number
  default     = 128
  description = "Range = [128,10240] : Lambda allocates CPU power in proportion to the amount of memory configured. You can increase or decrease the memory and CPU power allocated to your function using the Memory (MB) setting. At 1,769 MB, a function has the equivalent of one vCPU."
}

variable "scheduler_role_arn" {
  type        = string
  default     = ""
  description = "arn of the role that scheduler will assume"
}

variable "lambda_schedule" {
  type        = string
  default     = "rate(1 days)"
  description = "value of cron expression, default is daily at 12:00 PM UTC in reality it could be monthly"
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "[optional] insert key value pairs for lambda environment variables"
}

