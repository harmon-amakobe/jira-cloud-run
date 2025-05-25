# Grant Cloud Run service account access to Secret Manager secrets
resource "google_secret_manager_secret_iam_member" "jira_license_secret_accessor" {
  project   = google_secret_manager_secret.jira_license_secret.project
  secret_id = google_secret_manager_secret.jira_license_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "db_password_secret_accessor" {
  project   = google_secret_manager_secret.db_password_secret.project
  secret_id = google_secret_manager_secret.db_password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Grant Cloud Run service account access to the GCS bucket
resource "google_storage_bucket_iam_member" "jira_attachments_bucket_rw" {
  bucket = google_storage_bucket.jira_attachments_bucket.name
  role   = "roles/storage.objectAdmin" # Allows read, write, delete of objects
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Grant Cloud Run service account the Cloud SQL Client role for proxy connection
resource "google_project_iam_member" "cloud_run_sa_sql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Optional: Allow unauthenticated access to the Cloud Run service
# For production, remove 'allUsers' and grant to specific users/groups or use other authentication methods.
resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated_invokes" {
  project  = google_cloud_run_v2_service.jira_service.project
  name     = google_cloud_run_v2_service.jira_service.name
  location = google_cloud_run_v2_service.jira_service.location
  role     = "roles/run.invoker"
  member   = "allUsers" 
  
  // Add a condition or a separate variable to make this conditional
  // For example, using a variable:
  // count = var.allow_public_access ? 1 : 0 
  // (This would require defining var.allow_public_access)
}
