variable "project_id" {}

variable "secrets_dir" {}

variable "network" {}

variable "region" {}

variable "zone" {}

variable "controller_count" {
  default     = 3
  description = "Number of controllers in the Control Plane."
}

variable "controller_prefix" {
  default = "controller-"
}

variable "controller_tags" {
  default = [
    "kubernetes",
    "controller",
  ]
}

variable "worker_count" {
  default = 3
}

variable "worker_prefix" {
  default = "worker-"
}

variable "worker_preemptible" {
  default     = true
  description = "Whether all worker nodes are preemptible."
}

variable "worker_tags" {
  default = [
    "kubernetes",
    "worker",
  ]
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

variable "boot_disk_size" {
  description = "Disk size in GB."
  type        = map
  default = {
    dev   = 100,
    stage = 200,
  }
}

variable "worker_service_account_scopes" {
  default = [
    "cloud-platform",
  ]
}

variable "controller_service_account_scopes" {
  default = [
    "cloud-platform",
  ]
}

variable "bootstrap_token" {
  default     = ""
  description = "Auth token for TLS bootstrap. Keep it secret."
}

variable "ip_cidr_range" {
  default = "10.240.0.0/24" # Can host up to 254 compute instances.
}

variable "bootstrap_dir" {
  description = "Dir where the bootstrap scripts are."
  default     = "./modules/k8s"
}

variable "service_account_email" {
  description = "Service account to own the VMs."
}
