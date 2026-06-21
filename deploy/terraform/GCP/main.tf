# providers.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "services" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

module "network" {
  source = "./modules/network"
  region = var.region
}

module "gke" {
  source               = "./modules/gke"
  project_id           = var.project_id
  zone                 = var.zone
  network_self_link    = module.network.vpc_self_link
  subnetwork_self_link = module.network.subnet_self_link
}

# resource "google_compute_firewall" "sock_shop_nodeport" {
#   name        = "allow-sock-shop-nodeport"
#   network     = module.network.vpc_self_link
#   description = "Allow external access to Sock Shop frontend on NodePort ${var.nodeport}"

#   allow {
#     protocol = "tcp"
#     ports    = [var.nodeport]
#   }

#   source_ranges = ["0.0.0.0/0"]
#   target_tags   = [module.gke.node_tag]
# }
