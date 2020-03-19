terraform {
  backend "gcs" {
    credentials = "./secrets/Personal-4a45ab7e93d2.json"
    bucket      = "tf-state-floud"
    prefix      = "terraform/state"
  }
}

provider "google" {
  version = "3.5.0"

  credentials = file("${var.secrets_dir}/${var.credentials_file}")

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "floud" {
  name                    = "floud"
  auto_create_subnetworks = false # Custom.
}

module "k8s" {
  source = "./modules/k8s"

  network          = google_compute_network.floud.name
  region           = var.region
  zone             = var.zone
  secrets_dir      = "/Users/brunoflores/devel/kubernetes-the-hard-way/certs"
  controller_count = var.k8s_controller_count
  worker_count     = var.k8s_worker_count
  environment      = var.environment
  k8s_image        = var.k8s_image
  bootstrap_token  = var.k8s_bootstrap_token
  cidrs            = var.k8s_cidrs
}
