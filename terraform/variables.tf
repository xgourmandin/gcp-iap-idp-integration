variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "project_number" {
    description = "The GCP project number (can be found in GCP Console dashboard)."
    type        = string
}

variable "region" {
  description = "Default GCP region for Cloud Run services."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

# ─────────────────────────────────────────────
# DNS & Certificate
# ─────────────────────────────────────────────
variable "dns_zone_name" {
  description = "Name of the existing Cloud DNS managed zone to create records in."
  type        = string
}

variable "domain_name" {
  description = "Fully-qualified domain name for the load balancer (must belong to dns_zone_name). Example: demo.example.com"
  type        = string
}

# ─────────────────────────────────────────────
# IAP / Identity Platform
# ─────────────────────────────────────────────
variable "iap_support_email" {
  description = "Support email displayed on the IAP OAuth consent screen."
  type        = string
}

variable "iap_app_title" {
  description = "Application title shown on the IAP consent screen."
  type        = string
  default     = "IAP-IDP Demo"
}

# The IAP OAuth Admin API was deprecated on Jan 22 2025 and shut down Mar 19 2026.
# Create the OAuth 2.0 client manually:
#   GCP Console → APIs & Services → Credentials → Create Credentials → OAuth client ID
#   Application type: Web application
#   Authorised redirect URI: https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect
variable "iap_oauth2_client_id" {
  description = "OAuth 2.0 client ID for IAP (created manually in GCP Console)."
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────
# Sign-in app
# ─────────────────────────────────────────────

variable "signin_app_image" {
  description = "Docker image for the custom sign-in Cloud Run service. Override after building signin-app/."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}
