variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "region" {
  description = "Default GCP region for provider configuration."
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Globally unique name for the GCS bucket to create."
  type        = string
}

variable "bucket_location" {
  description = "GCS bucket location (region or multi-region, e.g. US, EU, us-central1)."
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

