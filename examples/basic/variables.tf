variable "hcp_tf_org" {
  type        = string
  description = "HCP Terraform Organization name"
}

variable "hcp_tf_token" {
  type        = string
  sensitive   = true
  description = "HCP Terraform API token"
}

variable "tf_run_task_logic_image" {
  type        = string
  description = "Docker image for the HCP Terraform run task logic"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_.]+/[a-zA-Z0-9-_.]+:[a-zA-Z0-9-_.]+$", var.tf_run_task_logic_image))
    error_message = "Invalid Docker image format. Expected format is <registry>/<image>:<tag>."
  }
}

variable "tf_run_task_logic_iam_roles" {
  type        = list(string)
  description = "values for the IAM roles to be used by the run task logic"
  default     = []
}

variable "region" {
  type        = string
  description = "AWS region to deploy the resources"
  default     = "us-east-1"
}

variable "tf_run_task_image_tag" {
  type        = string
  description = "value for the docker image tag to be used by the run task logic"
  default     = "latest"
}
