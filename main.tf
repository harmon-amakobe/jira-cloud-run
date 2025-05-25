terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Or a more recent stable version
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1" # Or a more recent stable version for random_id
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4 # Creates an 8-character hex string
}

locals {
  gcs_bucket_name_actual = format("%s-%s", var.gcs_bucket_name_prefix, random_id.bucket_suffix.hex)
  # Add other locals here if they become necessary
}

resource "google_project_service" "project_apis" {
  for_each = var.enable_apis ? toset([
    "compute.googleapis.com",             # Needed for VPC access, some network resources
    "sqladmin.googleapis.com",            # For Cloud SQL
    "secretmanager.googleapis.com",       # For Secret Manager
    "iam.googleapis.com",                 # For IAM
    "artifactregistry.googleapis.com",    # For Artifact Registry (where image is stored)
    "run.googleapis.com",                 # For Cloud Run
    "cloudbuild.googleapis.com",          # If Cloud Build is used for image, or by user
    "servicenetworking.googleapis.com"    # For private services access (Cloud SQL private IP)
  ]) : []

  project                    = var.gcp_project_id
  service                    = each.value
  disable_dependent_services = false # Set to true if you want to manage dependencies manually
  disable_on_destroy         = false # Set to true if you want APIs to be disabled on destroy (recommended: false)
}
