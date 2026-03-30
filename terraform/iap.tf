# ─────────────────────────────────────────────────────────────────
# IAP Settings — GCIP (Identity Platform) integration
#
# Tells IAP to use Identity Platform for authentication and redirect
# unauthenticated users to the custom sign-in application.
# ─────────────────────────────────────────────────────────────────

data google_secret_manager_secret_version "gcip_api_key" {
    secret = "firebase-apikey"
}

resource "google_iap_settings" "main" {
  provider = google-beta

  # Resource name: projects/{project}/iap_web/compute/services/{backendServiceName}
  name = "projects/${var.project_id}/iap_web/compute/services/${google_compute_backend_service.main.name}"

  access_settings {
    gcip_settings {
      tenant_ids = ["_${var.project_number}"]

      # IAP redirects unauthenticated users here.
      # gcip-iap in the sign-in app handles the auth flow.
      login_page_uri = "${google_cloud_run_v2_service.signin.uri}?apiKey=${data.google_secret_manager_secret_version.gcip_api_key.secret_data}"
    }
  }

  application_settings {
    access_denied_page_settings {
      access_denied_page_uri = "${google_cloud_run_v2_service.signin.uri}/access-denied"
    }
  }

  depends_on = [
    google_identity_platform_config.main,
    google_compute_backend_service.main,
  ]
}

# ─────────────────────────────────────────────────────────────────
# IAP Web access — grant authenticated users access to the backend.
# Uncomment and adjust members as needed.
# ─────────────────────────────────────────────────────────────────
# resource "google_iap_web_backend_service_iam_member" "example_user" {
#   project             = var.project_id
#   web_backend_service = google_compute_backend_service.main.name
#   role                = "roles/iap.httpsResourceAccessor"
#   member              = "user:alice@example.com"
# }
