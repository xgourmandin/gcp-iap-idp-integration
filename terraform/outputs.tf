output "load_balancer_ip" {
  description = "Global IP address of the external Application Load Balancer. Create an A record for var.domain_name pointing here."
  value       = google_compute_global_address.lb_ip.address
}

output "load_balancer_url" {
  description = "HTTPS endpoint of the demo application (IAP-protected)."
  value       = "https://${var.domain_name}/prod"
}

output "hello_world_cloud_run_url" {
  description = "Direct Cloud Run URL of the hello-world service (internal LB ingress only)."
  value       = google_cloud_run_v2_service.hello.uri
}

output "signin_app_cloud_run_url" {
  description = "Direct Cloud Run URL of the custom IAP sign-in application."
  value       = google_cloud_run_v2_service.signin.uri
}

output "iap_oauth_client_id" {
  description = "OAuth 2.0 client ID used by IAP (provided via variable)."
  value       = var.iap_oauth2_client_id
  sensitive   = true
}

output "certificate_map_id" {
  description = "Certificate Manager map ID attached to the HTTPS proxy."
  value       = google_certificate_manager_certificate_map.main.id
}

output "dns_challenge_record" {
  description = "CNAME challenge record that must propagate before the managed certificate activates."
  value = {
    name  = google_certificate_manager_dns_authorization.main.dns_resource_record[0].name
    type  = google_certificate_manager_dns_authorization.main.dns_resource_record[0].type
    value = google_certificate_manager_dns_authorization.main.dns_resource_record[0].data
  }
}
