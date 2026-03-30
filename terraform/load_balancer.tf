# ─────────────────────────────────────────────────────────────────
# Global IP address
# ─────────────────────────────────────────────────────────────────
resource "google_compute_global_address" "lb_ip" {
  name    = "iap-demo-lb-ip"
  project = var.project_id

  depends_on = [google_project_service.apis]
}

# ─────────────────────────────────────────────────────────────────
# Serverless NEG → Cloud Run hello-world
# ─────────────────────────────────────────────────────────────────
resource "google_compute_region_network_endpoint_group" "hello_neg" {
  name                  = "hello-world-neg"
  project               = var.project_id
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.hello.name
  }
}

# ─────────────────────────────────────────────────────────────────
# Backend service (IAP-protected)
# ─────────────────────────────────────────────────────────────────

data "google_secret_manager_secret_version" "iap_oauth2_client_secret" {
    secret = "iap-oauth2-client-secret"
}

resource "google_compute_backend_service" "main" {
  name                  = "iap-demo-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30

  backend {
    group = google_compute_region_network_endpoint_group.hello_neg.id
  }

  iap {
    enabled              = true
    oauth2_client_id     = var.iap_oauth2_client_id
    oauth2_client_secret = data.google_secret_manager_secret_version.iap_oauth2_client_secret.secret_data
  }

}

# ─────────────────────────────────────────────────────────────────
# URL Map — HTTPS
# Routes /prod and /prod/* to the IAP-protected backend.
# All other paths also land on the same backend (IAP still applies).
# ─────────────────────────────────────────────────────────────────
resource "google_compute_url_map" "main" {
  name            = "iap-demo-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.main.id

  host_rule {
    hosts        = [var.domain_name]
    path_matcher = "main-paths"
  }

  path_matcher {
    name            = "main-paths"
    default_service = google_compute_backend_service.main.id

    path_rule {
      paths   = ["/prod", "/prod/*"]
      service = google_compute_backend_service.main.id
    }
  }
}

# ─────────────────────────────────────────────────────────────────
# HTTPS Proxy (uses Certificate Map)
# ─────────────────────────────────────────────────────────────────
resource "google_compute_target_https_proxy" "main" {
  name    = "iap-demo-https-proxy"
  project = var.project_id
  url_map = google_compute_url_map.main.id

  # Reference the Certificate Manager map (not the legacy ssl_certificates list)
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.main.id}"
}

# ─────────────────────────────────────────────────────────────────
# HTTPS forwarding rule (port 443)
# ─────────────────────────────────────────────────────────────────
resource "google_compute_global_forwarding_rule" "https" {
  name                  = "iap-demo-https-rule"
  project               = var.project_id
  target                = google_compute_target_https_proxy.main.id
  port_range            = "443"
  ip_address            = google_compute_global_address.lb_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ─────────────────────────────────────────────────────────────────
# HTTP → HTTPS redirect (port 80)
# ─────────────────────────────────────────────────────────────────
resource "google_compute_url_map" "http_redirect" {
  name    = "iap-demo-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "iap-demo-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "iap-demo-http-rule"
  project               = var.project_id
  target                = google_compute_target_http_proxy.redirect.id
  port_range            = "80"
  ip_address            = google_compute_global_address.lb_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

