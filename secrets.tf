resource "google_secret_manager_secret" "jira_license_secret" {
  project   = var.gcp_project_id
  secret_id = "jira-license-key" // You can customize the secret_id

  replication {
    automatic = true
  }

  labels = {
    "description" = "Jira software license key"
    "environment" = "production" // Or as appropriate
  }
}

resource "google_secret_manager_secret_version" "jira_license_secret_version" {
  secret      = google_secret_manager_secret.jira_license_secret.id
  secret_data = var.jira_license_key

  # Ensure this version is created only after the secret itself is created
  depends_on = [google_secret_manager_secret.jira_license_secret]
}

resource "google_secret_manager_secret" "db_password_secret" {
  project   = var.gcp_project_id
  secret_id = "jira-db-password" // You can customize the secret_id

  replication {
    automatic = true
  }

  labels = {
    "description" = "Jira database user password"
    "environment" = "production" // Or as appropriate
  }
}

resource "google_secret_manager_secret_version" "db_password_secret_version" {
  secret      = google_secret_manager_secret.db_password_secret.id
  secret_data = var.db_password

  # Ensure this version is created only after the secret itself is created
  depends_on = [google_secret_manager_secret.db_password_secret]
}
