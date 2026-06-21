variable "project_id" {
  type        = string
  description = "The GCP Project ID where resources will be deployed."
}

variable "zone" {
  type        = string
  description = "The target availability zone for the GKE nodes."
}

variable "network_self_link" {
  type        = string
  description = "Self link of the VPC network the cluster attaches to."
}

variable "subnetwork_self_link" {
  type        = string
  description = "Self link of the subnet the cluster attaches to."
}