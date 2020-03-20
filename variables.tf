variable "project_id" {}

variable "project_number" {}

variable "credentials_file" {}

variable "environment" {}

variable "region" {
  default = "australia-southeast1"
}

variable "zone" {
  default = "australia-southeast1-a"
}

variable "secrets_dir" {
  default = "./secrets"
}

variable "k8s_controller_count" {}

variable "k8s_worker_count" {}

variable "k8s_image" {}

variable "k8s_bootstrap_token" {}

variable "k8s_cidrs" {}

variable "k8s_service_account_email" {
  description = "Service account to own the VMs."
}
