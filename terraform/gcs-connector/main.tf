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
  project               = var.project_id
}

provider "google-beta" {
  project               = var.project_id
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
  content_config              = "NO_CONTENT"
  solution_types              = [local.solution_type]
  create_advanced_site_search = false
}

# Import documents from GCS bucket to Discovery Engine datastore
# This creates the initial link between your GCS documents and the datastore
resource "null_resource" "import_documents" {
  depends_on = [
    google_discovery_engine_data_store.gemini_search_store,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      gcloud beta discovery-engine documents import \
        --project=${var.project_id} \
        --location=us \
        --data-store=${google_discovery_engine_data_store.gemini_search_store.data_store_id} \
        --source-bucket="gs://90187406059_80051816_us_import_content_with_faq_csv" \
        --format=document
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