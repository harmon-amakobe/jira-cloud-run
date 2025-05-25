# Jira on Google Cloud Run with Terraform and Filestore

This project provides Terraform configurations to deploy Atlassian Jira Software on Google Cloud Run, using Cloud SQL for MySQL as the database and Google Cloud Filestore for persistent `JIRA_HOME` storage.

## Overview

The deployment process involves two main phases:
1.  **Build and Push Jira Docker Image:** Use the provided `cloudbuild.yaml` to build the custom Jira Docker image (which includes MySQL compatibility) and push it to Google Artifact Registry. The entire `JIRA_HOME` (including attachments, indexes, plugins, etc.) is now persistently stored on Google Cloud Filestore, providing full data durability for the Jira instance.
2.  **Provision and Deploy Infrastructure:** Use Terraform to set up all necessary Google Cloud resources (Cloud SQL for MySQL instance, Filestore instance, Secret Manager secrets, Cloud Run service, IAM permissions, and a GCS bucket for potential backups or other uses) and deploy the Jira application using the Docker image from phase 1.

## Prerequisites

*   **Google Cloud Project:** With billing enabled.
*   **Google Cloud SDK (`gcloud`):** Installed and authenticated. Run `gcloud auth login` and `gcloud config set project YOUR_PROJECT_ID`.
*   **Terraform CLI:** Version 1.0 or later installed.
*   **Docker:** (Optional, if you wish to build the image locally. Cloud Build handles this remotely).
*   **Artifact Registry Repository:** Create an Artifact Registry Docker repository in your GCP project and region.
*   **Jira Software License Key:** You will need a valid Jira license.
*   **Database Password:** Choose a strong password for the Jira database user.
*   **Required APIs:** Ensure necessary APIs are enabled (e.g., Compute, SQL Admin, Secret Manager, IAM, Artifact Registry, Cloud Run, Service Networking, Filestore). If using Terraform with `enable_apis = true` (default), these will be enabled automatically. If deploying via Infrastructure Manager, ensure the underlying service account has permissions to enable them, or enable them manually beforehand.

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
    // gcs_bucket_name_prefix     = "my-custom-jira-bucket" // Bucket still created, e.g., for backups
    // cloud_run_service_name     = "my-jira"
    // cloud_run_service_account_name = "my-jira-sa"

    // Optional: Filestore settings (defaults are provided in variables.tf)
    // filestore_instance_name = "my-jira-filestore"
    // filestore_tier          = "BASIC_SSD"
    // filestore_capacity_gb   = 1024
    // filestore_share_name    = "jira_home"
    // filestore_network_name  = "default"
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
Due to `JIRA_HOME` being on Filestore for a standard Jira Software instance, the Cloud Run service is configured with `max_instances = 1` to ensure data integrity.

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
*   `gcs.tf`: GCS bucket (can be used for backups or other purposes, not live attachments).
*   `cloudsql.tf`: Cloud SQL for MySQL instance, database, and user.
*   `filestore.tf`: Google Cloud Filestore instance for `JIRA_HOME`.
*   `cloudrun.tf`: Cloud Run service deployment for Jira, configured with Filestore.
*   `iam.tf`: IAM permissions for the Cloud Run service account.
*   `outputs.tf`: Output values (like the Jira URL).

## Docker Image Details
*   `Dockerfile`: Defines the custom Jira image (MySQL compatible).
*   `startup_scripts/custom_entrypoint.sh`: Script run on container startup to configure Jira (no longer handles GCS sync for attachments).
*   `cloudbuild.yaml`: Cloud Build configuration to build and push the Docker image.

## Deploying with Google Cloud Infrastructure Manager

Google Cloud Infrastructure Manager provides a managed experience for deploying and managing Terraform configurations.

### Introduction
Infrastructure Manager allows you to:
*   Store your Terraform configurations in a Git repository.
*   Automate the deployment of your infrastructure based on your Terraform code.
*   Manage updates to your infrastructure by pushing changes to your Git repository.
*   View deployment status, outputs, and logs directly in the Google Cloud Console.
*   Use IAM to control who can deploy and manage infrastructure.

This is beneficial for this Jira solution as it streamlines the deployment process, integrates with version control, and provides a centralized management plane.

### Prerequisites for Infrastructure Manager
*   **Git Repository:** Your Terraform project (this repository) must be hosted in a Git repository (e.g., GitHub, Cloud Source Repositories) that Google Cloud can access.
*   **IAM Permissions for Infrastructure Manager Service Agent:** The Infrastructure Manager service agent (a Google-managed service account) needs permissions to impersonate the deployment service account. This is typically granted automatically when you enable the Infrastructure Manager API or during the first deployment if the user has sufficient project-level permissions. The role usually required is `roles/iam.serviceAccountTokenCreator` on the deployment service account.
*   **Deployment Service Account:** You need a user-managed service account that Infrastructure Manager will use to execute Terraform deployments. This service account must have sufficient IAM roles to create and manage all resources defined in your Terraform configuration (e.g., Project Editor, or more granular roles like Cloud SQL Admin, Filestore Editor, Cloud Run Admin, Secret Manager Admin, Storage Admin, Service Account User, etc.).
*   **Infrastructure Manager API Enabled:** The `config.googleapis.com` API must be enabled in your project.

### Deployment Steps with Infrastructure Manager

1.  **Enable Infrastructure Manager API:** If not already enabled, run:
    ```bash
    gcloud services enable config.googleapis.com --project=YOUR_PROJECT_ID
    ```
2.  **Navigate to Infrastructure Manager:** In the Google Cloud Console, search for "Infrastructure Manager" and navigate to the service.
3.  **Create a New Deployment:**
    *   Click "Deployments" and then "Create".
    *   **Deployment Name:** Give your deployment a descriptive name (e.g., `jira-production-deployment`).
    *   **Region:** Select the Google Cloud region where Infrastructure Manager will store its deployment metadata (this is separate from `var.gcp_region` where your Jira resources will be deployed).
4.  **Source Configuration:**
    *   **Source type:** Select "Git repository".
    *   **Repository URL:** Enter the URL of your Git repository.
    *   **Branch/Tag/Commit:** Specify the branch (e.g., `main`), tag, or commit hash to deploy from.
    *   **Terraform root directory:** If your Terraform files are not in the root of the repository, specify the path (e.g., `/terraform/`). For this project, it's typically the root (`/`).
5.  **Input Parameters:**
    *   Infrastructure Manager will automatically detect variables defined in `variables.tf`.
    *   You **must** provide values for variables without defaults:
        *   `gcp_project_id`: Your Google Cloud Project ID.
        *   `jira_license_key`: Your Jira Software license key.
        *   `db_password`: The password for the Jira database user.
        *   `jira_image_url`: The full URL of the Docker image you built in Phase 1 (e.g., `your-gcp-region-docker.pkg.dev/...`).
    *   You **should** review and confirm values for:
        *   `gcp_region`: The region where Jira and its resources will be deployed.
    *   You **can** customize other variables as needed (e.g., `filestore_instance_name`, `cloud_run_service_name`).
6.  **Service Account:**
    *   Select the user-managed service account that Infrastructure Manager will use to execute Terraform commands. This service account must have the necessary permissions to create all resources.
7.  **Review and Deploy:**
    *   Review all configurations.
    *   Click "Create" (or "Deploy"). Infrastructure Manager will fetch your Terraform configuration, initialize it, and effectively run `terraform apply`. You can monitor the progress in the console.

### Managing Existing Deployments
*   **View Details:** Click on your deployment name in the Infrastructure Manager console to see its status, revision history, applied configuration, outputs (from `outputs.tf`), and logs.
*   **Trigger Updates:**
    *   **Git-triggered (Automatic):** If your deployment is linked to a branch, pushing changes to that branch in your Git repository can automatically trigger a new revision and deployment in Infrastructure Manager (behavior might depend on settings).
    *   **Manual Updates:** You can manually edit the deployment (e.g., change input parameters, update the Git reference) and apply the changes.
*   **Destroying the Deployment:**
    *   To remove all resources managed by a deployment, select the deployment in the Infrastructure Manager console and choose the "Delete" or "Destroy" option. This will trigger a `terraform destroy` operation.

## Cleanup

To remove all resources created by Terraform:
1.  Navigate to the Terraform directory (if managing manually).
2.  Run the destroy command:
    ```bash
    terraform destroy
    ```
    Type `yes` when prompted.
**Note:** If you deployed using Google Cloud Infrastructure Manager, it is highly recommended to delete the deployment through the Infrastructure Manager console. This ensures that Infrastructure Manager correctly tracks the destruction of resources.
**Warning:** This will permanently delete the Cloud SQL instance (including data), Filestore instance (including `JIRA_HOME` data), GCS bucket, and other resources. Ensure you have backed up any critical data.

## Archived Manual Setup
Previous manual setup guides have been archived in the `docs/archive/` directory. The Terraform setup, preferably managed via Infrastructure Manager, is now the recommended method.
```
