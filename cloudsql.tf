# Required for Private IP an Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  project       = var.gcp_project_id
  name          = "jira-sql-private-ip-address" // Or make this configurable
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  ip_version    = "IPV4"
  network       = "default" // Assumes the default VPC network, make configurable if needed
}

resource "google_service_networking_connection" "private_vpc_connection" {
  project                 = var.gcp_project_id
  network                 = "default" // Assumes the default VPC network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  depends_on = [google_project_service.project_apis] # Ensure servicenetworking API is enabled
}

resource "google_sql_database_instance" "jira_mysql_instance" {
  project             = var.gcp_project_id
  name                = var.cloud_sql_instance_name
  region              = var.gcp_region
  database_version    = "MYSQL_8_0" // Or another appropriate version

  settings {
    tier    = "db-n1-standard-1" // Choose an appropriate tier for Jira
    disk_type = "PD_SSD"
    disk_size = 20 // Starting disk size in GB
    disk_autoresize = true

    ip_configuration {
      ipv4_enabled    = false // Disable public IP
      private_network = "projects/${var.gcp_project_id}/global/networks/default" // Assumes default VPC
      allocated_ip_range = google_compute_global_address.private_ip_address.name
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = true // Required for Point-in-Time Recovery
    }
    
    # Example of maintenance window
    # maintenance_window {
    #   day          = 1 # Monday
    #   hour         = 0 # Midnight
    #   update_track = "stable"
    # }

    # availability_type = "REGIONAL" # For High Availability, costs more
  }

  # Deletion protection is a good idea for production instances
  # deletion_protection = true 

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "jira_database" {
  project  = var.gcp_project_id
  instance = google_sql_database_instance.jira_mysql_instance.name
  name     = var.db_name
  charset  = "utf8mb4"
  collation = "utf8mb4_bin"
}

resource "google_sql_user" "jira_db_user" {
  project  = var.gcp_project_id
  instance = google_sql_database_instance.jira_mysql_instance.name
  name     = var.db_user_name
  password = google_secret_manager_secret_version.db_password_secret_version.secret_data

  // host should typically be '%' to allow connections from Cloud SQL Proxy
  // or specific IPs if not using proxy and IPs are known/static.
  // Default is typically fine when using Cloud SQL Proxy.
}
