# Jira on Google Cloud Run with Terraform and Filestore

This project provides Terraform configurations to deploy Atlassian Jira Software on Google Cloud Run. It leverages Cloud SQL for MySQL as the database and Google Cloud Filestore for persistent `JIRA_HOME` storage, ensuring full data durability.

This guide focuses on deploying the infrastructure using **Google Cloud Infrastructure Manager**, which is the recommended method for a managed, GitOps-driven deployment that uses Terraform (this project's IaC tool) to provision and manage your resources.

## Key Features
*   **Persistent `JIRA_HOME`:** Utilizes Google Cloud Filestore for the entire `JIRA_HOME` directory, including attachments, plugins, and indexes.
*   **Managed Database:** Leverages Cloud SQL for MySQL.
*   **Serverless Jira:** Runs Jira on Google Cloud Run.
*   **Automated Deployment:** Uses Terraform for infrastructure provisioning.
*   **Image Build Automation:** Includes `cloudbuild.yaml` for building the custom Jira Docker image.
*   **Secrets Management:** Integrates with Google Secret Manager for sensitive data like license keys and database passwords.

## Overview of Deployment Phases

The deployment process for this solution, using Google Cloud Infrastructure Manager, involves two main phases:

1.  **Phase 1: Build and Push Jira Docker Image:**
    *   A custom Jira Docker image, compatible with MySQL and designed for this setup, is built using Google Cloud Build.
    *   The image is then pushed to Google Artifact Registry.
    *   The key output of this phase is the **Jira Image URL**, which is a required input for the Infrastructure Manager deployment in Phase 2.
2.  **Phase 2: Provision and Deploy Infrastructure via Infrastructure Manager:**
    *   Google Cloud Infrastructure Manager uses the provided Terraform configurations to automatically set up all necessary Google Cloud resources:
        *   Cloud SQL for MySQL instance (database and user).
        *   Google Cloud Filestore instance (for `JIRA_HOME`).
        *   Google Secret Manager secrets (for Jira license and DB password).
        *   A GCS bucket (primarily for Terraform state or potential backups).
        *   Cloud Run service to host Jira, configured with Filestore.
        *   Necessary IAM permissions for secure operation.
    *   The Jira application is then deployed on Cloud Run using the Docker image from Phase 1.

## Prerequisites

This section outlines what you need to prepare *before* using Google Cloud Infrastructure Manager to deploy the Jira solution.

*   **Google Cloud Project:**
    *   An active Google Cloud Project with **billing enabled**. You will need the Project ID.
    *   Access this project via the Google Cloud Console.

*   **Google Cloud SDK (`gcloud` CLI):**
    *   **Installed and Authenticated:** The `gcloud` CLI must be installed on your local machine and authenticated with user credentials. This is essential for performing preliminary setup tasks that are not handled by Infrastructure Manager itself (e.g., initial API enablement, Artifact Registry creation, Cloud Build submission).
    *   **Key `gcloud` commands you will run:**
        *   `gcloud auth login`
        *   `gcloud config set project YOUR_PROJECT_ID`
        *   `gcloud services enable ...` (for enabling APIs)
        *   `gcloud artifacts repositories create ...` (for creating the Artifact Registry repo)
        *   `gcloud builds submit ...` (for building the Jira image)
        *   (Potentially) `gcloud iam service-accounts create ...` (for creating the Infrastructure Manager deployment SA if not done via Console)

*   **Artifact Registry Repository:**
    *   A Docker repository **must** be created in your Google Cloud project and chosen region *before* starting Phase 1 (Docker image build). This repository will store the custom Jira Docker image.
    *   **To create an Artifact Registry repository (example):**
      ```bash
      gcloud artifacts repositories create YOUR_ARTIFACT_REGISTRY_REPO_NAME \
        --repository-format=docker \
        --location=YOUR_GCP_REGION \
        --description="Jira Docker image repository" \
        --project=YOUR_PROJECT_ID
      ```
      Replace placeholders with your actual values.

*   **Jira Software License Key & Database Password:**
    *   These are sensitive values you will provide as input variables during the Infrastructure Manager deployment setup. The Terraform configuration will then store them securely in Google Secret Manager.

*   **Terraform CLI (Informational Only):**
    *   The Terraform CLI (Version 1.0 or later) is **not required** for deployment when using Infrastructure Manager, as Infrastructure Manager executes Terraform on your behalf. However, having it installed locally can be useful for those who wish to understand the Terraform code, perform local validation (`terraform validate`), or contribute to the IaC development.

*   **Docker (Informational Only):**
    *   Docker is **not required** on your local machine for deployment, as the provided setup uses Google Cloud Build for remote image building. It's only needed if you intend to build the Docker image locally for development or testing purposes.

*   **`jq` (Informational Only):**
    *   A command-line JSON processor. It is **not required** for deploying via Infrastructure Manager. It's mentioned as an optional tool for advanced users who might want to script interactions with GCP services or parse complex JSON outputs from `gcloud` commands or API responses outside of the Infrastructure Manager flow.

*   **IAM Permissions (User performing setup):**
    *   The Google Cloud user account you are authenticated as (via `gcloud auth login`) for running the initial `gcloud` commands (API enablement, Artifact Registry creation, Cloud Build submission) and for setting up the Infrastructure Manager deployment needs sufficient permissions on the project.
    *   For initial setup, roles like `roles/owner` or `roles/editor` are generally sufficient.
    *   For more granular control, ensure your user account has permissions to:
        *   Enable Google Cloud APIs (requires `roles/serviceusage.serviceUsageAdmin`).
        *   Create and manage Artifact Registry repositories (e.g., `roles/artifactregistry.admin`).
        *   Submit Cloud Build jobs (e.g., `roles/cloudbuild.builds.editor`).
        *   Create and manage IAM service accounts and grant them permissions (e.g., `roles/iam.serviceAccountAdmin`, `roles/resourcemanager.projectIamAdmin`).
        *   Configure and manage Google Cloud Infrastructure Manager deployments (e.g., `roles/config.admin`).

*   **Required APIs (to be enabled in your GCP Project):**
    *   The following Google Cloud APIs must be enabled in your project **before** initiating the Infrastructure Manager deployment (some are also needed for Phase 1). You can enable them using the `gcloud services enable ...` command provided below (this requires the user running the command to have `roles/serviceusage.serviceUsageAdmin` permissions).
    *   While the Terraform configuration includes `enable_apis = true` by default (which attempts to enable APIs via the Infrastructure Manager's deployment service account), it's best practice to pre-enable them, especially `config.googleapis.com` (Infrastructure Manager API) and `cloudbuild.googleapis.com`.
    *   **Command to enable all required APIs:**
      ```bash
      gcloud services enable \
          cloudresourcemanager.googleapis.com \
          compute.googleapis.com \
          sqladmin.googleapis.com \
          secretmanager.googleapis.com \
          iam.googleapis.com \
          artifactregistry.googleapis.com \
          run.googleapis.com \
          servicenetworking.googleapis.com \
          file.googleapis.com \
          config.googleapis.com \
          cloudbuild.googleapis.com \
          --project=YOUR_PROJECT_ID
      ```
    *   List of APIs:
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

    Once this phase is complete and you have the Jira Image URL, you are ready for Phase 2.

### Phase 2: Deploy Infrastructure with Google Cloud Infrastructure Manager

This is the **recommended method** for deploying and managing the Jira infrastructure. It uses Google Cloud Infrastructure Manager to orchestrate the Terraform deployment.

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

Once the Google Cloud Infrastructure Manager deployment completes successfully (which internally runs `terraform apply`), check the **Outputs** tab of your deployment in the Infrastructure Manager console. You will find the `cloud_run_service_url`. Access this URL in your browser to begin the Jira setup process.
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

To remove all resources created by this solution:

*   Navigate to **Google Cloud Infrastructure Manager** in the Google Cloud Console.
*   Select your deployment.
*   Choose the **"Delete"** option. This will trigger a `terraform destroy` operation managed by Infrastructure Manager, ensuring that all resources defined in the Terraform configuration are properly removed.

**Warning:** This action will permanently delete the Cloud SQL instance (including data), Filestore instance (including `JIRA_HOME` data), GCS bucket, and other resources. Ensure any critical data is backed up.

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
