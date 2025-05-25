variable "gcp_project_id" {
  type        = string
  description = "Google Cloud Project ID where resources will be deployed."
}

variable "gcp_region" {
  type        = string
  description = "Google Cloud Region for resource deployment."
  default     = "us-central1"
}

variable "jira_license_key" {
  type        = string
  description = "Jira software license key. This will be stored in Google Secret Manager."
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Password for the Jira database user. This will be stored in Google Secret Manager."
  sensitive   = true
}

variable "jira_image_url" {
  type        = string
  description = "Full URL of the pre-built Jira Docker image in Artifact Registry (e.g., us-central1-docker.pkg.dev/your-project/your-repo/jira-cloudrun-mysql:latest)."
}

variable "cloud_sql_instance_name" {
  type        = string
  description = "Name for the Cloud SQL instance."
  default     = "jira-mysql-instance"
}

variable "db_name" {
  type        = string
  description = "Name of the database to create in Cloud SQL for Jira."
  default     = "jiradb"
}

variable "db_user_name" {
  type        = string
  description = "Username for the Jira database user."
  default     = "jiradbuser"
}

variable "gcs_bucket_name_prefix" {
  type        = string
  description = "Prefix for the GCS bucket name. A random suffix will be added for uniqueness to meet global naming requirements."
  default     = "jira-attachments"
}

variable "cloud_run_service_name" {
  type        = string
  description = "Name for the Cloud Run service that will host Jira."
  default     = "jira-service"
}

variable "cloud_run_service_account_name" {
  type        = string
  description = "Name for the service account to be used by Cloud Run. If it doesn't exist, it will be created."
  default     = "jira-cloudrun-sa"
}

variable "enable_apis" {
  type        = bool
  description = "Enable necessary Google Cloud APIs (Compute, SQL Admin, Secret Manager, IAM, Artifact Registry, Cloud Run, Cloud Build, Service Networking)."
  default     = true
}
