provider "google" {
  version = "3.5.0"

  credentials = file("../secrets/Personal-4a45ab7e93d2.json")

  project = "396173368905"
  region  = "australia-southeast1"
  zone    = "australia-southeast1-a"
}

resource "google_compute_network" "vpc_network" {
  name = "floud"
}
