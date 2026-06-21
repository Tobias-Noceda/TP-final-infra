# variables.tf
variable "project_id" {
  type        = string
  description = "The GCP Project ID where resources will be deployed."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The primary GCP region for resources."
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "The target availability zone for the GKE nodes."
}

variable "nodeport" {
  type        = number
  default     = 30001
  description = "NodePort the Sock Shop front-end is exposed on; must match deploy.sh's NODEPORT."
}
