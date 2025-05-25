output "cloud_run_service_url" {
  description = "The URL of the deployed Jira Cloud Run service."
  value       = google_cloud_run_v2_service.jira_service.uri
}

output "actual_gcs_bucket_name" {
  description = "The actual name of the GCS bucket created for Jira attachments (includes random suffix)."
  value       = google_storage_bucket.jira_attachments_bucket.name
}

output "cloud_sql_instance_connection_name" {
  description = "The connection name of the Cloud SQL instance for Jira."
  value       = google_sql_database_instance.jira_mysql_instance.connection_name
}

output "cloud_run_service_account_email" {
  description = "The email of the service account created for the Cloud Run service."
  value       = google_service_account.cloud_run_sa.email
}

output "jira_license_secret_id" {
  description = "The ID of the Secret Manager secret storing the Jira license key."
  value       = google_secret_manager_secret.jira_license_secret.secret_id
}

output "db_password_secret_id" {
  description = "The ID of the Secret Manager secret storing the database password."
  value       = google_secret_manager_secret.db_password_secret.secret_id
}
