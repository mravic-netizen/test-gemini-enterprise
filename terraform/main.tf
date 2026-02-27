resource "google_project_service" "services" {
  for_each = toset([
    "aiplatform.googleapis.com",
    "discoveryengine.googleapis.com",
    "storage.googleapis.com"
  ])

  project = var.project_id
  service = each.key
}

resource "google_storage_bucket" "gemini_bucket" {
  name          = "${var.project_id}-gemini-data"
  location      = var.region
  force_destroy = true
  project       = var.project_id
}

resource "google_service_account" "gemini_sa" {
  account_id   = "gemini-enterprise-sa"
  display_name = "Gemini Enterprise SA"
  project      = var.project_id
}

resource "google_project_iam_member" "gemini_roles" {
  for_each = toset([
    "roles/aiplatform.admin",
    "roles/discoveryengine.admin",
    "roles/storage.admin"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gemini_sa.email}"
}

resource "google_discovery_engine_data_store" "gemini_datastore" {
  location          = "global"
  data_store_id     = "gemini-datastore"
  display_name      = "Gemini Enterprise Datastore"
  industry_vertical = "GENERIC"
  content_config    = "CONTENT_REQUIRED"
}

resource "google_discovery_engine_search_engine" "gemini_app" {
  location      = "global"
  collection_id = "default_collection"
  engine_id     = var.app_name
  display_name  = "Gemini Enterprise App"

  search_engine_config {
    search_tier = "SEARCH_TIER_STANDARD"
  }

  data_store_ids = [
    google_discovery_engine_data_store.gemini_datastore.data_store_id
  ]
}