variable "role_names" {
  description = "The name of the IAM role to attach policies to."
  type        = list(string)
}

variable "policy_names" {
  description = "List of policy names to attach to the IAM role."
  type        = list(string)
}

variable "policy_descriptions" {
  description = "List of policy descriptions."
  type        = list(string)
}

variable "policy_documents" {
  description = "List of policy documents (JSON) to attach to the IAM role."
  type        = list(string)
}

resource "aws_iam_policy" "attached_policies" {
  count       = length(var.policy_names)
  name        = var.policy_names[count.index]
  description = var.policy_descriptions[count.index]
  policy      = var.policy_documents[count.index]
}

resource "aws_iam_policy_attachment" "attachment" {
  count      = length(var.policy_names)
  name       = "${var.policy_names[count.index]}-policy-attachment"
  roles      = var.role_names
  policy_arn = aws_iam_policy.attached_policies[count.index].arn
}
