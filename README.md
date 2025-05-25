# Jira on Google Cloud Run with Terraform and Filestore

This project provides Terraform configurations to deploy Atlassian Jira Software on Google Cloud Run. It leverages Cloud SQL for MySQL as the database and Google Cloud Filestore for persistent `JIRA_HOME` storage, ensuring full data durability.

This guide focuses on deploying the infrastructure using **Google Cloud Infrastructure Manager**, which is the recommended method for a managed, GitOps-driven deployment.

For users who prefer direct Terraform CLI interaction, an alternative manual deployment guide is available in the "Advanced: Direct Terraform CLI Usage" section.

## Key Features
*   **Persistent `JIRA_HOME`:** Utilizes Google Cloud Filestore for the entire `JIRA_HOME` directory, including attachments, plugins, and indexes.
*   **Managed Database:** Leverages Cloud SQL for MySQL.
*   **Serverless Jira:** Runs Jira on Google Cloud Run.
*   **Automated Deployment:** Uses Terraform for infrastructure provisioning.
*   **Image Build Automation:** Includes `cloudbuild.yaml` for building the custom Jira Docker image.
*   **Secrets Management:** Integrates with Google Secret Manager for sensitive data like license keys and database passwords.

## Overview of Deployment Phases

Regardless of the deployment method (Terraform CLI or Infrastructure Manager), the process involves two main phases:

1.  **Phase 1: Build and Push Jira Docker Image:**
    *   A custom Jira Docker image, compatible with MySQL and designed for this setup, is built using Google Cloud Build.
    *   The image is then pushed to Google Artifact Registry.
    *   The key output of this phase is the **Jira Image URL**, which is required for infrastructure deployment.
2.  **Phase 2: Provision and Deploy Infrastructure:**
    *   Terraform configurations are used to set up all necessary Google Cloud resources:
        *   Cloud SQL for MySQL instance (database and user).
        *   Google Cloud Filestore instance (for `JIRA_HOME`).
        *   Google Secret Manager secrets (for Jira license and DB password).
        *   A GCS bucket (primarily for Terraform state or potential backups).
        *   Cloud Run service to host Jira, configured with Filestore.
        *   Necessary IAM permissions for secure operation.
    *   The Jira application is then deployed on Cloud Run using the Docker image from Phase 1.

## Prerequisites

Before you begin, ensure you have the following:

*   **Google Cloud Project:** An active project with billing enabled. You will need the Project ID.
*   **Google Cloud SDK (`gcloud`):** Installed and authenticated with appropriate user credentials. Run `gcloud auth login` and `gcloud config set project YOUR_PROJECT_ID`. This is essential for running `gcloud` commands (like submitting the build or enabling APIs).
*   **Terraform CLI:** Version 1.0 or later installed. While Infrastructure Manager executes Terraform, having the CLI installed is useful for understanding the configuration, local validation (e.g., `terraform validate`), or if you choose the "Advanced: Direct Terraform CLI Usage" path.
*   **Docker:** (Optional) Only needed if you intend to build the Docker image locally. Cloud Build handles this remotely by default.
*   **Artifact Registry Repository:** A Docker repository **must** be created in your Google Cloud project and the chosen region *before* Phase 1. This repository will store the custom Jira Docker image.
*   **Jira Software License Key:** A valid license for Jira Software. This will be stored securely in Secret Manager.
*   **Database Password:** A strong password for the Jira database user. This will also be stored securely in Secret Manager.
*   **`jq` (Optional but Recommended):** A command-line JSON processor, useful if you plan to script interactions with Terraform outputs (more relevant for the Direct CLI path).
*   **IAM Permissions (User):** The user account running `gcloud` commands (e.g., for Cloud Build, API enablement, or setting up Infrastructure Manager) needs sufficient permissions. Typically, roles like `roles/owner` or `roles/editor` on the project are sufficient for initial setup. For more granular permissions, ensure the user can:
    *   Enable necessary APIs.
    *   Create and manage Cloud Build jobs (e.g., `roles/cloudbuild.builds.editor`).
    *   Create Artifact Registry repositories (if not already done).
    *   Create and manage service accounts (for Infrastructure Manager deployment).
    *   Grant IAM permissions to service accounts.
    *   Set up Infrastructure Manager deployments.
*   **Required APIs:** Ensure the following Google Cloud APIs are enabled in your project. The user running `gcloud services enable ...` or the Infrastructure Manager's deployment service account (if `enable_apis=true` in Terraform) needs `roles/serviceusage.serviceUsageAdmin` or equivalent permissions.
    *   `cloudresourcemanager.googleapis.com` (Cloud Resource Manager API)
    *   `compute.googleapis.com` (Compute Engine API)
    *   `sqladmin.googleapis.com` (Cloud SQL Admin API)
    *   `secretmanager.googleapis.com` (Secret Manager API)
    *   `iam.googleapis.com` (Identity and Access Management (IAM) API)
    *   `artifactregistry.googleapis.com` (Artifact Registry API)
    *   `run.googleapis.com` (Cloud Run API)
    *   `servicenetworking.googleapis.com` (Service Networking API - for VPC peering)
    *   `file.googleapis.com` (Cloud Filestore API)
    *   `config.googleapis.com` (Infrastructure Manager API - essential for the recommended deployment path)
    *   `cloudbuild.googleapis.com` (Cloud Build API - for building the Docker image in Phase 1)

## Deployment Steps

### Phase 1: Build and Push Jira Docker Image

This phase uses Google Cloud Build to create the custom Jira Docker image. The image is then pushed to your Artifact Registry repository. **Completing this phase and obtaining the full Jira Image URL is a critical prerequisite before proceeding to Phase 2 (Infrastructure Deployment).**

1.  **Ensure your Artifact Registry repository is created** in your Google Cloud project and chosen region.
2.  **Navigate to the repository root directory** (where `cloudbuild.yaml` and `Dockerfile` are located).
3.  **Submit the build to Google Cloud Build:**
    Execute the following command, replacing the placeholders with your specific values:
    ```bash
    gcloud builds submit --config cloudbuild.yaml --substitutions=\
_GCP_REGION=your-gcp-region,\
_ARTIFACT_REGISTRY_REPO=your-artifact-registry-repo-name,\
_IMAGE_NAME=your-jira-image-name,\
_IMAGE_TAG=latest
    ```
    *   `your-gcp-region`: The Google Cloud region where your Artifact Registry repository exists (e.g., `us-central1`).
    *   `your-artifact-registry-repo-name`: The name of your Artifact Registry repository.
    *   `your-jira-image-name`: The desired name for your Jira Docker image (e.g., `jira-filestore-app`).
4.  **Note the Jira Image URL:** After a successful build, Cloud Build will output the image URL. It will look something like:
    `your-gcp-region-docker.pkg.dev/your-gcp-project-id/your-artifact-registry-repo-name/your-jira-image-name:latest`.
    This full URL is the `jira_image_url` required for the Infrastructure Manager deployment in Phase 2.

    Once this phase is complete, you are ready to deploy the infrastructure using Google Cloud Infrastructure Manager.

### Phase 2: Deploy Infrastructure with Google Cloud Infrastructure Manager (Recommended)

Google Cloud Infrastructure Manager provides a managed service for deploying and managing Terraform configurations, offering a streamlined and GitOps-friendly approach.

##### Introduction to Infrastructure Manager
Infrastructure Manager allows you to:
*   Store your Terraform configurations in a Git repository.
*   Automate infrastructure deployment based on your Terraform code.
*   Manage infrastructure updates by pushing changes to your Git repository.
*   View deployment status, outputs, and logs in the Google Cloud Console.
*   Use IAM for granular control over deployment and management.
This method is beneficial for streamlining deployments, integrating with version control, and providing a centralized management plane.

##### Prerequisites for Infrastructure Manager
*   **Git Repository:** Your Terraform project (this repository) must be hosted in a Git repository (e.g., GitHub, Cloud Source Repositories) that Google Cloud can access. If using a private repository, you may need to configure access credentials.
*   **IAM Permissions for Infrastructure Manager Service Agent:** The Infrastructure Manager service agent (a Google-managed service account) needs permission to impersonate the *deployment service account* (see below). This is typically granted automatically when you enable the Infrastructure Manager API or during the first deployment if the user has sufficient project-level permissions. The required role is `roles/iam.serviceAccountTokenCreator` on the *deployment service account*.
*   **Deployment Service Account (User-Managed):** Create a user-managed service account that Infrastructure Manager will use to execute Terraform. This account needs sufficient IAM roles to manage all resources in your Terraform configuration.
    *   **Recommended Granular Roles (assign to the Deployment SA):**
        *   `roles/cloudsql.admin` (Cloud SQL Admin)
        *   `roles/storage.admin` (Storage Admin - for GCS bucket)
        *   `roles/run.admin` (Cloud Run Admin)
        *   `roles/file.editor` (Filestore Editor)
        *   `roles/secretmanager.admin` (Secret Manager Admin)
        *   `roles/iam.serviceAccountAdmin` (Service Account Admin - to create Cloud Run SA)
        *   `roles/resourcemanager.projectIamAdmin` (Project IAM Admin - to grant permissions to Cloud Run SA)
        *   `roles/servicenetworking.serviceAgent` (Service Networking Connections Admin - for VPC peering)
        *   `roles/serviceusage.serviceUsageAdmin` (Service Usage Admin - to enable APIs if `enable_apis = true`)
    *   **Alternative (Broader Permissions):** `roles/editor` (Project Editor) on the project. Use with caution.
*   **Infrastructure Manager API Enabled:** The `config.googleapis.com` API (and others listed in general prerequisites) must be enabled in your project.

##### Deployment Steps with Infrastructure Manager

1.  **Ensure APIs are Enabled:** Verify that all APIs listed in the main "Prerequisites" section (including `config.googleapis.com`) are enabled in your project.
    ```bash
    gcloud services enable config.googleapis.com \
        cloudresourcemanager.googleapis.com \
        compute.googleapis.com \
        sqladmin.googleapis.com \
        secretmanager.googleapis.com \
        iam.googleapis.com \
        artifactregistry.googleapis.com \
        run.googleapis.com \
        servicenetworking.googleapis.com \
        file.googleapis.com \
        cloudbuild.googleapis.com \
        --project=YOUR_PROJECT_ID
    ```
2.  **Create and Configure Deployment Service Account:**
    If not already done, create a user-managed service account. Grant it the recommended IAM roles listed above.
    ```bash
    gcloud iam service-accounts create YOUR_DEPLOYMENT_SA_NAME --display-name="Infra Manager Jira Deployment SA" --project=YOUR_PROJECT_ID
    # Grant roles, e.g.:
    # gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:YOUR_DEPLOYMENT_SA_NAME@YOUR_PROJECT_ID.iam.gserviceaccount.com" --role="roles/cloudsql.admin"
    # (Repeat for all recommended roles)
    ```
3.  **Navigate to Infrastructure Manager:** In the Google Cloud Console, search for "Infrastructure Manager".
4.  **Create a New Deployment:**
    *   Click "Deployments", then "Create".
    *   **Deployment Name:** Enter a name (e.g., `jira-prod-deployment`).
    *   **Region:** Select the region for Infrastructure Manager metadata storage (this is separate from `var.gcp_region` for Jira resources).
5.  **Configure Source:**
    *   **Source type:** "Git repository".
    *   **Repository URL:** Enter the HTTPS URL of your Git repository (e.g., `https://github.com/your-username/your-repo-name.git`).
    *   **Target reference type:** "Branch".
    *   **Target reference:** Your branch name (e.g., `main`).
    *   **Terraform configuration directory:** Leave blank if `.tf` files are at the repository root.
6.  **Configure Inputs (Variables):**
    *   Infrastructure Manager auto-detects variables from `variables.tf`.
    *   **Required Variables:** Provide values for variables without defaults:
        *   `gcp_project_id`
        *   `jira_license_key` (handle this sensitive input carefully as per Infrastructure Manager's recommendations for secrets, though Terraform itself places it in Secret Manager)
        *   `db_password` (handle similarly)
        *   `jira_image_url` (from Phase 1)
    *   **Review Defaults:** Verify other variables like `gcp_region`.
    *   **Customize Optional Variables:** Adjust others (e.g., `filestore_instance_name`) if needed.
7.  **Select Service Account:**
    *   Choose the user-managed service account created in Step 2 (e.g., `YOUR_DEPLOYMENT_SA_NAME@YOUR_PROJECT_ID.iam.gserviceaccount.com`). Infrastructure Manager uses this to run Terraform.
8.  **Review and Deploy:**
    *   Review all settings. Click "Create". Infrastructure Manager fetches the Terraform code, runs `terraform apply`, and manages the deployment.
    *   Monitor progress, logs, and outputs in the Infrastructure Manager console.

##### Managing Existing Deployments
*   **View Details:** Access deployment status, revision history, outputs, and logs in the console.
*   **Trigger Updates:** Push changes to your Git repository (if linked to a branch) or manually edit the deployment to apply updates.
*   **Destroying the Deployment:** Use the "Delete" or "Destroy" option in the Infrastructure Manager console for the specific deployment.

## Accessing Jira

Once `terraform apply` (via CLI or Infrastructure Manager) completes successfully, check the Terraform outputs for `cloud_run_service_url`. Access this URL in your browser to begin the Jira setup process.
Due to `JIRA_HOME` being on Filestore, the Cloud Run service is configured with `max_instances = 1` to ensure data integrity for standard Jira Software.

## Terraform Outputs

The following outputs will be displayed after a successful deployment:
*   `cloud_run_service_url`: The URL of your Jira instance.
*   `actual_gcs_bucket_name`: The name of the GCS bucket created (e.g., for Terraform state, backups).
*   `cloud_sql_instance_connection_name`: The connection name of your Cloud SQL instance.
*   `cloud_run_service_account_email`: The service account used by Cloud Run.
*   `jira_license_secret_id`: The Secret Manager ID for the Jira license.
*   `db_password_secret_id`: The Secret Manager ID for the DB password.

## Cleanup

To remove all resources created by Terraform:
1.  **If using Terraform CLI:**
    *   Navigate to the Terraform directory.
    *   Run: `terraform destroy`
    *   Type `yes` when prompted.
2.  **If using Google Cloud Infrastructure Manager (Recommended):**
    *   It is **highly recommended** to delete the deployment through the Infrastructure Manager console. This ensures Infrastructure Manager correctly tracks resource destruction.

**Warning:** This action will permanently delete the Cloud SQL instance (including data), Filestore instance (including `JIRA_HOME` data), GCS bucket, and other resources. Ensure any critical data is backed up.

## Advanced: Direct Terraform CLI Usage

For users who prefer or require direct interaction with Terraform via the CLI, follow these steps. This path offers more granular control but requires manual execution of Terraform commands.

1.  **Navigate to the directory containing the Terraform files** (e.g., the root of this repository).
2.  **Create `terraform.tfvars` file:**
    This file is used to provide your specific configuration values to Terraform. Create a new file named `terraform.tfvars` in the same directory as your `.tf` files.
    **Important:** Do not commit `terraform.tfvars` to version control if it contains sensitive data, unless you are certain that variables holding sensitive data (like `jira_license_key` and `db_password`) are correctly marked as `sensitive = true` in `variables.tf` (which they are in this project).

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
    // filestore_capacity_gb   = 1024 // Minimum for BASIC_SSD/HDD is 1024GB
    // filestore_share_name    = "jira_home"
    // filestore_network_name  = "default"
    ```
3.  **Initialize Terraform:**
    This command downloads the necessary provider plugins.
    ```bash
    terraform init
    ```
4.  **Review the execution plan:**
    This command shows you what resources Terraform will create, modify, or delete.
    ```bash
    terraform plan
    ```
5.  **Apply the configuration:**
    This command provisions the resources in Google Cloud.
    ```bash
    terraform apply
    ```
    Type `yes` when prompted to confirm. This process can take several minutes, especially for the Cloud SQL and Filestore instance creation.
    Remember to manage your Terraform state file appropriately.

## Performance Profiles & Estimated Monthly Costs

For detailed guidance on Jira resource requirements, please refer to Atlassian's official documentation, such as their [Jira Sizing Guide](https://confluence.atlassian.com/adminjiraserver/jira-sizing-guide-938846809.html). The configurations below are examples.

**Disclaimer:**
*   The following costs are estimates based on configurations in the `us-central1` region and are subject to change. Actual costs can vary significantly based on your specific configuration, usage patterns, region, network traffic, and current Google Cloud pricing. These estimates do **not** include Jira software licensing fees.
*   Always use the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) for a more accurate and tailored cost projection.

### Small/Starter Jira Instance (Default Configuration)

The default Terraform variables in this project are configured for a small or starter Jira instance. This setup is suitable for smaller teams or initial evaluations.

Example workload: Up to 20-25 users, ~5,000-10,000 issues, light to moderate daily usage. Performance will vary based on specific usage patterns, add-ons, and configurations.

| Component             | Default Configuration (Example)                      | Estimated Monthly Cost (USD) | Notes / Assumptions                                                                                                                               |
|-----------------------|------------------------------------------------------|------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Cloud Run Service     | 1 instance (max), 2 vCPU, 8GiB RAM                   | ~$180 - $200                 | Assumes instance is provisioned continuously (e.g., min_instances=1 or CPU always allocated). Cost varies with request volume and CPU utilization. |
| Cloud SQL for MySQL   | `db-n1-standard-1` (1 vCPU, 3.75GB RAM), 20GB SSD    | ~$50 - $70                   | Includes instance and storage. Backups and network traffic can add to costs.                                                                    |
| Cloud Filestore       | Basic SSD tier, 1024 GB capacity                     | ~$300 - $310                 | Minimum capacity for Basic SSD tier.                                                                                                              |
| Google Cloud Storage  | Standard Storage, 10GB                               | ~$0.20 - $0.30               | For the created bucket (e.g., for Terraform state, potential future backups). Does not include significant data storage for backups by user.      |
| Google Secret Manager | 2 secrets, ~2 versions each                          | ~$0                          | Likely within the free tier for this small number of secrets and access operations.                                                               |
| Networking (Egress) | Based on usage                                       | Variable                     | Costs depend on data transferred out of Google Cloud. Intra-region traffic is often free or low-cost.                                           |
| **Total Estimated Range (Small/Starter)** |                                  | **~$530 - $580+ / month**    | **Excludes Jira license fees and variable networking costs.**                                                                                       |

### Medium-Sized Jira Instance

For a medium-sized Jira instance, such as one handling approximately 20-50 daily active users, 40-50 projects, 10,000-50,000 issues, and up to 500 custom fields, you will need to override some default variables or adjust Terraform configurations. This configuration aims for better performance and capacity for such a workload.

**Recommended Variable Overrides / Configuration Adjustments:**
*   **Cloud Run:** You may need to adjust `cloudrun.tf` to increase CPU to `"4"` and memory to `"16Gi"` for the Cloud Run container, as these are not currently parameterized as input variables.
*   **Cloud SQL:** You may need to adjust `cloudsql.tf` to set the `settings.tier` to `"db-n1-standard-4"` for the `google_sql_database_instance` resource, and potentially increase `disk_size` to `50` (GB) or more, as these are not currently input variables.
*   **Filestore:** The default 1TB Basic SSD for Filestore (`filestore_capacity_gb = 1024`, `filestore_tier = "BASIC_SSD"`) is often a good starting point for medium instances, but monitor disk space and performance. These are configurable via `variables.tf`.

**Estimated Costs for Medium Profile:**

| Component             | Configuration Example                                | Estimated Monthly Cost (USD) | Notes / Assumptions                                                                                                                               |
|-----------------------|------------------------------------------------------|------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Cloud Run Service     | 1 instance (max), 4 vCPU, 16GiB RAM                  | ~$360 - $400                 | Assumes instance is provisioned continuously.                                                                                                     |
| Cloud SQL for MySQL   | `db-n1-standard-4` (4 vCPU, 15GB RAM), 50GB SSD      | ~$210 - $240                 | Increased tier and storage for higher load. Backups and network traffic can add to costs.                                                       |
| Cloud Filestore       | Basic SSD tier, 1024 GB capacity                     | ~$300 - $310                 | Monitor performance and capacity. Enterprise tier offers higher performance at higher cost if needed.                                           |
| Google Cloud Storage  | Standard Storage, 10GB                               | ~$0.20 - $0.30               | For the created bucket. Usage for backups may increase this.                                                                                      |
| Google Secret Manager | 2 secrets, ~2 versions each                          | ~$0                          | Likely within the free tier.                                                                                                                      |
| Networking (Egress) | Based on usage                                       | Variable                     | Costs depend on data transferred out of Google Cloud.                                                                                             |
| **Total Estimated Range (Medium)** |                                          | **~$870 - $950+ / month**    | **Excludes Jira license fees and variable networking costs.**                                                                                       |

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

## Archived Manual Setup
Previous manual setup guides have been archived in the `docs/archive/` directory. The Terraform setup, preferably managed via Infrastructure Manager, is now the recommended method.
```
