# First, define the service account Cloud Run will use
resource "google_service_account" "cloud_run_sa" {
  project      = var.gcp_project_id
  account_id   = var.cloud_run_service_account_name
  display_name = "Service Account for Jira Cloud Run service"
}

resource "google_cloud_run_v2_service" "jira_service" {
  project  = var.gcp_project_id
  name     = var.cloud_run_service_name
  location = var.gcp_region

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image = var.jira_image_url
      ports {
        container_port = 8080 // Default Jira port
      }

      resources {
        limits = {
          cpu    = "2"     // Example: 2 CPUs
          memory = "8Gi"   // Example: 8GB RAM, Jira is memory intensive
        }
        startup_cpu_boost = true
      }

      env {
        name  = "DB_HOST"
        value = "127.0.0.1" // For Cloud SQL Proxy
      }
      env {
        name  = "DB_PORT"
        value = "3306"
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_USER"
        value = var.db_user_name
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password_secret.secret_id
            version = "latest" // Or specific version like google_secret_manager_secret_version.db_password_secret_version.version
          }
        }
      }
      env {
        name  = "GCS_BUCKET_NAME"
        value = local.gcs_bucket_name_actual
      }
      env {
        name = "JIRA_LICENSE_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jira_license_secret.secret_id
            version = "latest" // Or specific version
          }
        }
      }
      env {
        name  = "JIRA_HOME"
        value = "/mnt/jira_home"
      }
      volume_mounts {
        name       = "jira-home-filestore" // Must match the volume name above
        mount_path = "/mnt/jira_home"      // The path inside the container
      }
       # Optional: Add JIRA_MAX_PERM_SIZE if needed by your Jira version/plugins
      # env {
      #   name = "JVM_MAXIMUM_MEMORY"
      #   value = "6144m" // Example, should be less than container memory limit
      # }
      # env {
      #   name = "JVM_MINIMUM_MEMORY"
      #   value = "2048m" // Example
      # }
    }

    # Cloud SQL Connection (enables built-in proxy)
    cloud_sql_instance {
      instances = [google_sql_database_instance.jira_mysql_instance.connection_name]
    }
    
    volumes {
      name = "jira-home-filestore" // A logical name for the volume
      nfs {
        server    = google_filestore_instance.jira_home_filestore.networks[0].ip_addresses[0]
        path      = "/${var.filestore_share_name}" // Path on the NFS server (e.g., /jira_home)
        read_only = false
      }
    }

    scaling {
      min_instance_count = 0 // Can be 0 for scale-to-zero, or 1 for always-on (once started)
      max_instance_count = 1
    }
    
    // Set a longer startup timeout as Jira can be slow to start
    // This is not directly available in google_cloud_run_v2_service container spec
    // but can be influenced by probes or instance settings.
    // For v2, the execution_environment can be set to GEN2 for longer startup.
    // Default timeout for requests is also important.
    // Consider adding startup_probe if Jira takes a long time.
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Allow unauthenticated access for simplicity in testing.
  # For production, you'd likely want to restrict this.
  # This is managed via IAM policy on the service.
  # `google_cloud_run_v2_service_iam_binding` can set `roles/run.invoker` to `allUsers` or specific users/groups.

  depends_on = [
    google_sql_database_instance.jira_mysql_instance,
    google_secret_manager_secret_version.jira_license_secret_version,
    google_secret_manager_secret_version.db_password_secret_version,
    google_service_account.cloud_run_sa,
    google_filestore_instance.jira_home_filestore
  ]
}
