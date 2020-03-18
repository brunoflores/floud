variable "project" {}

variable "credentials_file" {}

variable "region" {
  default = "australia-southeast1"
}

variable "zone" {
  default = "australia-southeast1-a"
}

variable "controller_count" {
  default = 3
}

variable "controller_prefix" {
  default = "controller-"
}

variable "worker_count" {
  default = 1
}

variable "worker_prefix" {
  default = "worker-"
}

variable "worker_preemptible" {
  default     = true
  description = "Whether all worker nodes are preemptible."
}

variable "cidrs" {
  default = []
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "machine_type" {
  type = map
  default = {
    dev   = "f1-micro"
    stage = "n1-standard-1"
  }
}

variable "k8s_image" {
  default     = "floud-k8s-v1-0-0"
  description = "Disk image used for all k8s VMs."
}

variable "secrets_dir" {
  default = "./secrets"
}

variable "bootstrap_token" {
  default     = ""
  description = "Auth token for TLS bootstrap. Keep it secret."
}
