resource "google_container_cluster" "primary" {
  name     = "gke-cluster"
  location = var.zone

  # Best practice: Delete the default node pool to manage it independently
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  # Recent provider versions default this true, which blocks `terraform destroy`.
  deletion_protection = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Workload Identity enables safe pod authentication to GCP services
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Custom Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "gke-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_locations = [var.zone] # Ensure nodes are in the same zone as the cluster

  node_config {
    preemptible  = false
    machine_type = "e2-standard-2"

    # Static tag so the nodeport firewall rule can target nodes without
    # querying GKE's auto-generated per-cluster tag at apply time.
    tags = ["gke-sock-shop-node"]

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}