terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.20"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

locals {
  solution_type = "SOLUTION_TYPE_SEARCH"
  app_type      = "APP_TYPE_INTRANET"
  name_prefix   = "gemini-enterprise"
  company_name  = "ASCO testing"
}
# Generates a random suffix for Gemini resources (Data Store, Engine) to allow easy recreation
resource "random_id" "gemini_suffix" {
  byte_length = 4
  keepers = {
    solution_type = local.solution_type
    app_type      = local.app_type
    name_prefix   = local.name_prefix
  }
}
# Data Store (Empty and not connected to any sources)
resource "google_discovery_engine_data_store" "gemini_search_store" {
  location                    = var.location
  data_store_id               = "${local.name_prefix}-data-store-${random_id.gemini_suffix.hex}"
  display_name                = "Gemini Search Data Store ${random_id.gemini_suffix.hex}"
  industry_vertical           = "GENERIC"
  content_config              = "CONTENT_REQUIRED"
  solution_types              = [local.solution_type]
  create_advanced_site_search = false
}

# Import documents from GCS bucket to Discovery Engine datastore
# This creates the initial link between your GCS documents and the datastore
resource "null_resource" "import_documents" {
  depends_on = [
    google_discovery_engine_data_store.gemini_search_store,
  ]
  
# Optional: Add a trigger to re-run import if bucket contents change significantly
  triggers = {
    gcs_uri   = var.gcs_import_uri
    data_store_id = google_discovery_engine_data_store.gemini_search_store.data_store_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      TOKEN=$(gcloud auth print-access-token)

      curl -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json; charset=utf-8" \
      -d '{
        "gcsSource": {
          "inputUris": ["${var.gcs_import_uri}/*"],
          "dataSchema": "content"
        },
        "reconciliationMode": "INCREMENTAL"
      }' \
      "https://${var.location == "global" ? "" : "${var.location}-"}discoveryengine.googleapis.com/v1beta/projects/${var.project_id}/locations/${var.location}/collections/default_collection/dataStores/${google_discovery_engine_data_store.gemini_search_store.data_store_id}/branches/0/documents:import"
    EOT
  }
}

resource "google_discovery_engine_search_engine" "gemini_search_engine" {
  engine_id         = "${local.name_prefix}-engine-${random_id.gemini_suffix.hex}"
  collection_id     = "default_collection"
  location          = google_discovery_engine_data_store.gemini_search_store.location
  display_name      = "Gemini Enterprise (${random_id.gemini_suffix.hex})"
  industry_vertical = "GENERIC"
  data_store_ids    = [google_discovery_engine_data_store.gemini_search_store.data_store_id]
  app_type          = local.app_type

  common_config {
    company_name = local.company_name
  }

  features = {
    "agent-sharing-without-admin-approval" = "FEATURE_STATE_ON"
    "disable-agent-sharing"                = "FEATURE_STATE_OFF"
  }

  search_engine_config {
  }

  knowledge_graph_config {
  }
}
