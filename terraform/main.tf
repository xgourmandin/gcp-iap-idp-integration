terraform {
  required_version = ">= 1.14.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "main" {
  name          = var.bucket_name
  location      = var.bucket_location
  project       = var.project_id
  force_destroy = false

  # Prevent public access
  public_access_prevention = "enforced"

  # Uniform bucket-level access (IAM-only, no ACLs)
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

