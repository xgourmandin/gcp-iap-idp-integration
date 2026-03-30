# ─────────────────────────────────────────────────────────────────
# DNS Authorization
# Proves domain ownership so Certificate Manager can issue a cert.
# ─────────────────────────────────────────────────────────────────
resource "google_certificate_manager_dns_authorization" "main" {
  name        = "iap-demo-dns-auth"
  project     = var.project_id
  description = "DNS authorization for ${var.domain_name}"
  domain      = var.domain_name

  depends_on = [google_project_service.apis]
}

# CNAME record in your Cloud DNS zone — must propagate before the cert activates.
resource "google_dns_record_set" "cert_challenge" {
  project      = var.project_id
  managed_zone = var.dns_zone_name

  name    = google_certificate_manager_dns_authorization.main.dns_resource_record[0].name
  type    = google_certificate_manager_dns_authorization.main.dns_resource_record[0].type
  ttl     = 300
  rrdatas = [google_certificate_manager_dns_authorization.main.dns_resource_record[0].data]
}

# ─────────────────────────────────────────────────────────────────
# Google-managed Certificate
# ─────────────────────────────────────────────────────────────────
resource "google_certificate_manager_certificate" "main" {
  name    = "iap-demo-cert"
  project = var.project_id

  managed {
    domains            = [var.domain_name]
    dns_authorizations = [google_certificate_manager_dns_authorization.main.id]
  }

  # Certificate provisioning starts only after the CNAME record exists
  depends_on = [google_dns_record_set.cert_challenge]
}

# ─────────────────────────────────────────────────────────────────
# Certificate Map (attached to HTTPS proxy)
# ─────────────────────────────────────────────────────────────────
resource "google_certificate_manager_certificate_map" "main" {
  name    = "iap-demo-cert-map"
  project = var.project_id
}

resource "google_certificate_manager_certificate_map_entry" "main" {
  name         = "iap-demo-cert-map-entry"
  project      = var.project_id
  map          = google_certificate_manager_certificate_map.main.name
  certificates = [google_certificate_manager_certificate.main.id]
  hostname     = var.domain_name
}

# ─────────────────────────────────────────────────────────────────
# A record pointing domain → load balancer IP
# ─────────────────────────────────────────────────────────────────
resource "google_dns_record_set" "lb_a" {
  project      = var.project_id
  managed_zone = var.dns_zone_name

  # Terraform requires the trailing dot for absolute DNS names
  name    = "${var.domain_name}."
  type    = "A"
  ttl     = 300
  rrdatas = [google_compute_global_address.lb_ip.address]
}

