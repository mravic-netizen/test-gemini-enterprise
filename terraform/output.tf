output "app_id" {
  value = google_discovery_engine_search_engine.gemini_app.search_engine_id
}

output "bucket_name" {
  value = google_storage_bucket.gemini_bucket.name
}