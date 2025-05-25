# Jira on Google Cloud Run with Terraform

This project provides Terraform configurations to deploy Atlassian Jira Software on Google Cloud Run, using Cloud SQL for MySQL as the database and Google Cloud Storage (GCS) for attachments.

## Overview

The deployment process involves two main phases:
1.  **Build and Push Jira Docker Image:** Use the provided `cloudbuild.yaml` to build the custom Jira Docker image (which includes MySQL compatibility and GCS integration scripts) and push it to Google Artifact Registry.
2.  **Provision and Deploy Infrastructure:** Use Terraform to set up all necessary Google Cloud resources (GCS bucket, Cloud SQL for MySQL instance, Secret Manager secrets, Cloud Run service, IAM permissions) and deploy the Jira application using the Docker image from phase 1.

## Prerequisites

*   **Google Cloud Project:** With billing enabled.
*   **Google Cloud SDK (`gcloud`):** Installed and authenticated. Run `gcloud auth login` and `gcloud config set project YOUR_PROJECT_ID`.
*   **Terraform CLI:** Version 1.0 or later installed.
*   **Docker:** (Optional, if you wish to build the image locally. Cloud Build handles this remotely).
*   **Artifact Registry Repository:** Create an Artifact Registry Docker repository in your GCP project and region.
*   **Jira Software License Key:** You will need a valid Jira license.
*   **Database Password:** Choose a strong password for the Jira database user.

## Deployment Steps

### Phase 1: Build and Push Jira Docker Image

The custom Jira Docker image includes necessary configurations for MySQL and GCS.

1.  **Navigate to the repository root.**
2.  **Submit the build to Google Cloud Build:**
    ```bash
    gcloud builds submit --config cloudbuild.yaml --substitutions=\
      _GCP_REGION=your-gcp-region,\
      _ARTIFACT_REGISTRY_REPO=your-artifact-registry-repo-name,\
      _IMAGE_NAME=your-jira-image-name,\
      _IMAGE_TAG=latest 
    ```
    Replace `your-gcp-region`, `your-artifact-registry-repo-name`, and `your-jira-image-name` with your values.
3.  **Note the Image URL:** After a successful build, Cloud Build will output the image URL. It will look something like: `your-gcp-region-docker.pkg.dev/your-gcp-project-id/your-artifact-registry-repo-name/your-jira-image-name:latest`. You will need this for the Terraform configuration.

### Phase 2: Deploy Infrastructure with Terraform

1.  **Navigate to the directory containing the Terraform files** (e.g., the root of this repository).
2.  **Create `terraform.tfvars` file:**
    Create a file named `terraform.tfvars` in the same directory and populate it with your specific values. **Do not commit this file to version control if it contains sensitive information not managed by variables marked `sensitive = true` directly (though `jira_license_key` and `db_password` are handled correctly as sensitive by `variables.tf`).**

    Example `terraform.tfvars`:
    ```terraform
    gcp_project_id     = "your-gcp-project-id"
    gcp_region         = "your-gcp-region" // e.g., "us-central1"
    jira_license_key   = "YOUR-JIRA-LICENSE-KEY"
    db_password        = "YourSecureP@ssw0rd!"
    jira_image_url     = "your-gcp-region-docker.pkg.dev/your-gcp-project-id/your-repo/your-image:tag" // From Phase 1

    // Optional: Override other defaults from variables.tf if needed
    // cloud_sql_instance_name    = "my-custom-jira-db"
    // gcs_bucket_name_prefix     = "my-custom-jira-bucket"
    // cloud_run_service_name     = "my-jira"
    // cloud_run_service_account_name = "my-jira-sa"
    ```
3.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
4.  **Review the plan:**
    ```bash
    terraform plan
    ```
    This will show you what resources Terraform will create.
5.  **Apply the configuration:**
    ```bash
    terraform apply
    ```
    Type `yes` when prompted to confirm. This process may take several minutes as it provisions the Cloud SQL instance and other resources.

## Accessing Jira

Once `terraform apply` is complete, check the Terraform outputs for `cloud_run_service_url`. Access this URL in your browser to begin the Jira setup process.

## Terraform Outputs

The following outputs will be displayed after a successful deployment:
*   `cloud_run_service_url`: The URL of your Jira instance.
*   `actual_gcs_bucket_name`: The name of the GCS bucket created for attachments.
*   `cloud_sql_instance_connection_name`: The connection name of your Cloud SQL instance.
*   `cloud_run_service_account_email`: The service account used by Cloud Run.
*   `jira_license_secret_id`: The Secret Manager ID for the Jira license.
*   `db_password_secret_id`: The Secret Manager ID for the DB password.

## Cleanup

To remove all resources created by Terraform:
1.  Navigate to the Terraform directory.
2.  Run the destroy command:
    ```bash
    terraform destroy
    ```
    Type `yes` when prompted.
**Warning:** This will permanently delete the Cloud SQL instance (including data), GCS bucket (including attachments), and other resources. Ensure you have backed up any critical data.

## Terraform File Overview
*   `main.tf`: Core provider configuration, API enablement, and local variables.
*   `variables.tf`: Input variables for customization.
*   `secrets.tf`: Secret Manager resources for Jira license and DB password.
*   `gcs.tf`: GCS bucket for Jira attachments.
*   `cloudsql.tf`: Cloud SQL for MySQL instance, database, and user.
*   `cloudrun.tf`: Cloud Run service deployment for Jira.
*   `iam.tf`: IAM permissions for the Cloud Run service account.
*   `outputs.tf`: Output values (like the Jira URL).

## Docker Image Details
*   `Dockerfile`: Defines the custom Jira image (MySQL compatible, GCS integration).
*   `startup_scripts/custom_entrypoint.sh`: Script run on container startup to configure Jira.
*   `cloudbuild.yaml`: Cloud Build configuration to build and push the Docker image.

## Archived Manual Setup
Previous manual setup guides have been archived in the `docs/archive/` directory. The Terraform setup is now the recommended method.
```
