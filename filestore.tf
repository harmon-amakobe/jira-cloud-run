resource "google_filestore_instance" "jira_home_filestore" {
  project  = var.gcp_project_id
  name     = var.filestore_instance_name
  location = var.gcp_region // Filestore instances are regional, not zonal.
  tier     = var.filestore_tier

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = var.filestore_share_name
    // NFS export options can be added here if specific settings are needed
    // nfs_export_options {
    //   ip_ranges   = ["0.0.0.0/0"] // Example: Allow all IPs in the VPC. Be more specific if possible.
    //   access_mode = "READ_WRITE"
    //   squash_mode = "NO_ROOT_SQUASH"
    // }
  }

  networks {
    network = var.filestore_network_name // e.g., "default" or a specific VPC network name
    modes   = ["MODE_IPV4"] // Or as appropriate for your network setup
    // reserved_ip_range can be specified if you have a specific IP range for Filestore
  }

  labels = {
    "purpose"     = "jira-home-persistence"
    "environment" = "production" // Or as appropriate
  }

  // Depends on the Filestore API being enabled
  depends_on = [google_project_service.project_apis]
}
