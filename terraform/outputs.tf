output "bucket_name" {
  description = "The name of the created GCS bucket."
  value       = google_storage_bucket.main.name
}

output "bucket_url" {
  description = "The self-link URL of the created GCS bucket."
  value       = google_storage_bucket.main.self_link
}

output "bucket_location" {
  description = "The location of the created GCS bucket."
  value       = google_storage_bucket.main.location
}

