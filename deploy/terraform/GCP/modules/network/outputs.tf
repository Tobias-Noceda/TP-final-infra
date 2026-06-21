output "vpc_id" {
  value       = google_compute_network.vpc.id
  description = "ID of the VPC network."
}

output "vpc_self_link" {
  value       = google_compute_network.vpc.self_link
  description = "Self link of the VPC network."
}

output "subnet_id" {
  value       = google_compute_subnetwork.subnet.id
  description = "ID of the GKE subnet."
}

output "subnet_self_link" {
  value       = google_compute_subnetwork.subnet.self_link
  description = "Self link of the GKE subnet."
}
