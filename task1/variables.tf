variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "spaces_access_key_id" {
  description = "DigitalOcean Spaces access key"
  type        = string
  sensitive   = true
}

variable "spaces_secret_access_key" {
  description = "DigitalOcean Spaces secret key"
  type        = string
  sensitive   = true
}

variable "project_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "kondrasiuk"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "fra1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.10.0/24"
}

variable "droplet_size" {
  description = "Droplet size for Minikube/Kubernetes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_key_ids" {
  description = "List of SSH key fingerprints or IDs"
  type        = list(string)
  default     = []
}
