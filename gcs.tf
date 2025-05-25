resource "google_storage_bucket" "jira_attachments_bucket" {
  project                     = var.gcp_project_id
  name                        = local.gcs_bucket_name_actual # Using the unique name from locals
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  storage_class               = "STANDARD" // Or another class if preferred

  versioning {
    enabled = true
  }

  labels = {
    "purpose"     = "jira-attachments"
    "environment" = "production" // Or as appropriate
  }

  // Optional: Lifecycle rules for managing old versions or moving to colder storage
  // lifecycle_rule {
  //   action {
  //     type = "Delete"
  //   }
  //   condition {
  //     num_newer_versions = 10
  //   }
  // }
  // lifecycle_rule {
  //   action {
  //     type = "SetStorageClass"
  //     storage_class = "NEARLINE"
  //   }
  //   condition {
  //     days_since_noncurrent_time = 30
  //     num_newer_versions = 5
  //   }
  // }
}
