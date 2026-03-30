# ─────────────────────────────────────────────────────────────────
# Hello-world demo service
# Ingress restricted to internal LB only; IAP is the auth gate.
# ─────────────────────────────────────────────────────────────────
resource "google_cloud_run_v2_service" "hello" {
  name     = "hello-world"
  location = var.region
  project  = var.project_id

  # Only accept traffic that comes through an internal (LB) path
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    containers {
      # Official GCP demo container
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [google_project_service.apis]
}

# ─────────────────────────────────────────────────────────────────
# Custom IAP sign-in application
# Public ingress required so IAP can redirect unauthenticated users
# to this page. The page itself performs no sensitive operations.
# ─────────────────────────────────────────────────────────────────
resource "google_cloud_run_v2_service" "signin" {
  name     = "iap-signin-app"
  location = var.region
  project  = var.project_id

  # Must be publicly accessible – IAP redirects browsers here
  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      # Replace with your built image after: docker push <registry>/signin-app
      image = var.signin_app_image

      env {
        name  = "FIREBASE_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "FIREBASE_API_KEY"
        value = data.google_secret_manager_secret_version.gcip_api_key.secret_data
      }

      # Populate these via Secret Manager references or CI/CD env injection:
      #   FIREBASE_AUTH_DOMAIN   – <project-id>.firebaseapp.com

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [google_project_service.apis]
}

resource "google_cloud_run_v2_service_iam_member" "signin_allow_all" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.signin.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ─────────────────────────────────────────────────────────────────
# IAP service account (P4SA)
#
# google_project_service_identity ensures the per-product service
# account for IAP (service-PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com)
# is provisioned before we try to bind it to Cloud Run.
# ─────────────────────────────────────────────────────────────────
resource "google_project_service_identity" "iap" {
  provider = google-beta
  project  = var.project_id
  service  = "iap.googleapis.com"
}

# Grant the IAP SA permission to invoke the IAP-protected Cloud Run service.
# Without this, IAP can authenticate the user but cannot forward the request
# to Cloud Run, producing the "IAP service account is not provisioned" error.
resource "google_cloud_run_v2_service_iam_member" "hello_iap_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_project_service_identity.iap.email}"
}

