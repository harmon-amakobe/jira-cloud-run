# Jira on Google Cloud Run with Terraform and Filestore

This project provides Terraform configurations to deploy Atlassian Jira Software on Google Cloud Run, using Cloud SQL for MySQL and Google Cloud Filestore for persistent `JIRA_HOME` storage.

This guide focuses on deploying the infrastructure using **Google Cloud Infrastructure Manager**, the recommended method for a managed, GitOps-driven deployment. Infrastructure Manager uses this project's Terraform code to provision and manage your Google Cloud resources.

## Key Features
*   **Persistent `JIRA_HOME`:** Utilizes Google Cloud Filestore for the entire `JIRA_HOME` directory, including attachments, plugins, and indexes.
*   **Managed Database:** Leverages Cloud SQL for MySQL.
*   **Serverless Jira:** Runs Jira on Google Cloud Run.
*   **Automated Deployment:** Uses Terraform for infrastructure provisioning.
*   **Image Build Automation:** Includes `cloudbuild.yaml` for building the custom Jira Docker image.
*   **Secrets Management:** Integrates with Google Secret Manager for sensitive data like license keys and database passwords.

## Sourcing the Terraform Configuration for Infrastructure Manager

When using Google Cloud Infrastructure Manager, you must provide it with a source for the Terraform configurations. Using your own controlled copy of this Terraform code (rather than directly using this public repository) is crucial for stability, customization, and avoiding unexpected impacts from upstream changes. Here are your options:

### Option 1: Forking the Repository (Recommended)

This is the **best practice**. Forking creates a personal copy of this repository under your Git account (e.g., GitHub, GitLab). This allows you to manage updates from the original repository at your own pace and make customizations if needed.

*   **Action:** Use the "Fork" button on this repository's page on your Git provider.
*   **Result:** You will use the URL of *your forked repository* when configuring Infrastructure Manager.

### Option 2: Cloning and Pushing to Your Own Repository

This gives you a completely new repository under your full control.

*   **Action:**
    1.  Clone this repository locally:
        ```bash
        # Replace <URL_OF_THIS_REPOSITORY> with the actual URL of this project's repository
        git clone <URL_OF_THIS_REPOSITORY> jira-on-cloudrun-terraform
        cd jira-on-cloudrun-terraform
        ```
    2.  Create a new, empty repository on your preferred Git provider.
    3.  Update the remote origin of your local clone and push the code to your new repository:
        ```bash
        git remote set-url origin <URL_OF_YOUR_NEW_REPOSITORY> 
        git push -u origin main # Or your default branch name
        ```
*   **Result:** You will use the URL of *your new repository* when configuring Infrastructure Manager.

### Option 3: Using This Public Repository Directly (Not Recommended)

Pointing Infrastructure Manager directly to this public repository is **not recommended for production or long-term use.** Upstream changes could unexpectedly impact your deployment, and you cannot customize the configuration.

### Repository Accessibility for Google Cloud

Ensure the Git repository you use (your fork or new repository) is accessible to Google Cloud.
*   **Public Repositories:** Generally accessible without special configuration.
*   **Private Repositories:** You may need to configure access, often by connecting your Git provider to your Google Cloud project (e.g., via Cloud Build connections) or using Cloud Source Repositories. Refer to Google Cloud documentation for details.

## Overview of Deployment Phases

The deployment process involves two main phases:

1.  **Phase 1: Build and Push Jira Docker Image:**
    *   The custom Jira Docker image (MySQL-compatible) is built using Google Cloud Build.
    *   This image is then pushed to Google Artifact Registry.
    *   **Output:** The **Jira Image URL**, required for the Infrastructure Manager deployment.
2.  **Phase 2: Provision and Deploy Infrastructure via Infrastructure Manager:**
    *   Infrastructure Manager uses this project's Terraform configurations to set up all necessary Google Cloud resources:
        *   Cloud SQL for MySQL instance.
        *   Google Cloud Filestore instance for `JIRA_HOME`.
        *   Google Secret Manager secrets (for Jira license and DB password).
        *   A GCS bucket (primarily for Terraform state or potential backups).
        *   Cloud Run service to host Jira, configured with Filestore.
        *   Necessary IAM permissions for secure operation.
    *   The Jira application is then deployed on Cloud Run using the Docker image from Phase 1.

## Prerequisites

This section outlines what you need to prepare *before* using Google Cloud Infrastructure Manager to deploy the Jira solution. Most `gcloud` commands can be run directly in **Google Cloud Shell**.

*   **Google Cloud Project:**
    *   An active Google Cloud Project with **billing enabled**. You will need the Project ID.
    *   Access to this project via the Google Cloud Console.

*   **Google Cloud SDK (`gcloud` via Cloud Shell):**
    *   Certain setup steps require `gcloud` commands. These are best run in **Google Cloud Shell**, accessible from the Google Cloud Console. Cloud Shell provides a pre-authenticated `gcloud` environment.
    *   Ensure your Cloud Shell is configured for your target project: `gcloud config set project YOUR_PROJECT_ID`.
    *   You will use `gcloud` for tasks like enabling APIs, creating an Artifact Registry repository (if not using the Console), submitting the Cloud Build job, and potentially creating service accounts.

*   **Artifact Registry Repository:**
    *   A Docker repository **must** be created in your Google Cloud project and chosen region *before* Phase 1.
    *   Create this via the **Google Cloud Console** (Navigate to "Artifact Registry" > "Create Repository", select "Docker" format) or **Cloud Shell**:
      ```bash
      gcloud artifacts repositories create YOUR_ARTIFACT_REGISTRY_REPO_NAME \
        --repository-format=docker \
        --location=YOUR_GCP_REGION \
        --description="Jira Docker image repository" \
        --project=YOUR_PROJECT_ID 
      ```
      (Replace placeholders like `YOUR_ARTIFACT_REGISTRY_REPO_NAME`).

*   **Jira Software License Key & Database Password:**
    *   Have these sensitive values ready. You'll provide them as input variables during the Infrastructure Manager deployment, and Terraform will store them securely in Google Secret Manager.

*   **IAM Permissions (User performing setup):**
    *   Your Google Cloud user account (used in Cloud Shell/Console) needs permissions for the initial setup tasks (API enablement, Artifact Registry, Cloud Build, Infrastructure Manager setup).
    *   Roles like `roles/owner` or `roles/editor` on the project are sufficient for initial setup. For more granular permissions, ensure your user can:
        *   Enable Google Cloud APIs (`roles/serviceusage.serviceUsageAdmin`).
        *   Manage Artifact Registry repositories (`roles/artifactregistry.admin`).
        *   Submit Cloud Build jobs (`roles/cloudbuild.builds.editor`).
        *   Manage IAM service accounts and permissions (`roles/iam.serviceAccountAdmin`, `roles/resourcemanager.projectIamAdmin`).
        *   Manage Infrastructure Manager deployments (`roles/config.admin`).

*   **Required APIs (to be enabled in your GCP Project):**
    *   The following APIs must be enabled. Use the Google Cloud Console ("APIs & Services" > "Library") or the `gcloud` command in Cloud Shell. It's best practice to pre-enable these, especially `config.googleapis.com` and `cloudbuild.googleapis.com`, even if Terraform (`enable_apis = true`) attempts it.
    *   **Command to enable all required APIs (run in Cloud Shell):**
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

There are two primary ways to initiate this build:

**Method 1: Using `gcloud` command in Google Cloud Shell (Recommended for simplicity)**

1.  **Ensure your Artifact Registry repository is created** (see Prerequisites).
2.  **Access your Source Code in Cloud Shell:**
    *   Open **Google Cloud Shell**.
    *   If you have forked or cloned this repository (as recommended in "Sourcing the Terraform Configuration"), clone your repository into the Cloud Shell environment:
        ```bash
        git clone https://github.com/YOUR_USERNAME/YOUR_FORKED_REPO_NAME.git
        cd YOUR_FORKED_REPO_NAME 
        ```
        (Replace with your actual repository URL and directory name).
    *   Ensure the `cloudbuild.yaml`, `Dockerfile`, and the `startup_scripts/` directory are present in your current directory.
3.  **Submit the build to Google Cloud Build from Cloud Shell:**
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

**Method 2: Using the Google Cloud Console with Cloud Build Triggers**

This method is useful if you prefer a UI-driven approach and want to set up automated builds (though not strictly necessary for a one-time deployment).

1.  **Ensure your Artifact Registry repository is created** (see Prerequisites).
2.  **Connect your Git Repository to Cloud Build:**
    *   In the Google Cloud Console, navigate to "Cloud Build" > "Triggers".
    *   Click "Connect repository" and follow the prompts to connect to your Git provider (e.g., GitHub) and select your forked/cloned repository.
3.  **Create a Build Trigger (or Run Manually):**
    *   Once the repository is connected, you can create a trigger that automatically starts a build on code pushes to a specific branch.
    *   Alternatively, for a manual build:
        *   Go to "Cloud Build" > "History".
        *   Click "Run Build".
        *   Select your connected repository and branch/commit.
        *   **Configuration:** Choose "Cloud Build configuration file (yaml or json)".
        *   **Location:** Specify `/cloudbuild.yaml` (or the path to your build config if it's in a subdirectory).
        *   **Substitution Variables:** Add the following variables and their values:
            *   `_GCP_REGION`: Your GCP region (e.g., `us-central1`).
            *   `_ARTIFACT_REGISTRY_REPO`: Your Artifact Registry repository name.
            *   `_IMAGE_NAME`: Your desired image name (e.g., `jira-filestore-app`).
            *   `_IMAGE_TAG`: `latest` (or your preferred tag).
        *   Click "Run build".
4.  **Note the Jira Image URL:** After the build completes successfully, find the image URL in the build logs or by navigating to Artifact Registry and locating your image.

Whichever method you choose, once this phase is complete and you have the Jira Image URL, you are ready for Phase 2.

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
    *   **Recommended Granular Roles (assign to the Deployment SA):** `roles/cloudsql.admin`, `roles/storage.admin`, `roles/run.admin`, `roles/file.editor`, `roles/secretmanager.admin`, `roles/iam.serviceAccountAdmin`, `roles/resourcemanager.projectIamAdmin`, `roles/servicenetworking.serviceAgent`, `roles/serviceusage.serviceUsageAdmin`.
    *   **Alternative (Broader Permissions):** `roles/editor` on the project (use with caution).
*   **Infrastructure Manager API Enabled:** The `config.googleapis.com` API must be enabled (see "Required APIs" in general Prerequisites).

##### Deployment Steps with Infrastructure Manager

1.  **Ensure all general "Prerequisites" are met**, especially API enablement and Artifact Registry repository creation. The Jira Docker image from Phase 1 must be available.
2.  **Create and Configure Deployment Service Account:**
    This service account is used by Infrastructure Manager to deploy resources. It can be created and its IAM roles granted through the **Google Cloud Console** (IAM & Admin > Service Accounts, then IAM page) or via **Cloud Shell**:
    ```bash
    # Create the Service Account (replace YOUR_DEPLOYMENT_SA_NAME)
    gcloud iam service-accounts create YOUR_DEPLOYMENT_SA_NAME \
      --display-name="Infrastructure Manager Jira Deployment SA" \
      --project=YOUR_PROJECT_ID

    # Grant necessary roles (repeat for all roles listed in "Prerequisites for Infrastructure Manager")
    # Example for one role:
    gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
      --member="serviceAccount:YOUR_DEPLOYMENT_SA_NAME@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
      --role="roles/cloudsql.admin" 
    ```
3.  **Navigate to Infrastructure Manager:** In the Google Cloud Console, search for "Infrastructure Manager" and go to the service.
4.  **Create a New Deployment:**
    *   Click "Deployments", then "Create".
    *   **Deployment Name:** Enter a descriptive name (e.g., `jira-prod-deployment`).
    *   **Region:** Select the region for Infrastructure Manager metadata storage (this is separate from `var.gcp_region` where Jira resources will be deployed).
5.  **Configure Source:**
    *   **Source type:** "Git repository".
    *   **Repository URL:** Provide the HTTPS URL of **your forked or cloned Git repository**. Example: `https://github.com/YOUR_USERNAME/YOUR_FORKED_REPO_NAME.git`.
    *   **Target reference type:** "Branch".
    *   **Target reference:** Your branch name (e.g., `main`).
    *   **Terraform configuration directory:** Leave blank if `.tf` files are at the repository root.
6.  **Configure Inputs (Terraform Variables):**
    *   Infrastructure Manager auto-detects variables from `variables.tf`.
    *   **Provide Required Variables:**
        *   `gcp_project_id`: Your Google Cloud Project ID.
        *   `jira_license_key`: Your Jira Software license key. (Handle this sensitive input as per Infrastructure Manager's recommendations for secrets).
        *   `db_password`: The password for the Jira database user. (Handle similarly).
        *   `jira_image_url`: The full Jira Image URL from Phase 1.
    *   **Review Defaults:** Verify other variables like `gcp_region`.
    *   **Customize Optional Variables:** Adjust others (e.g., `filestore_instance_name`) if needed.
7.  **Select Deployment Service Account:**
    *   Choose the user-managed service account you created and configured in Step 2. Infrastructure Manager will use this account to execute Terraform.
8.  **Review and Deploy:**
    *   Carefully review all settings. Click "Create".
    *   Infrastructure Manager fetches the Terraform code, runs `terraform apply`, and manages the deployment. Monitor progress, logs, and outputs in the Infrastructure Manager console.

##### Managing Existing Deployments
*   **View Details:** Access deployment status, revision history, outputs, and logs in the console.
*   **Update Deployments:** Push changes to your Git repository (if linked to a branch) or manually edit the deployment in the console to apply updates.
*   **Destroy Deployments:** Use the "Delete" or "Destroy" option in the Infrastructure Manager console for the specific deployment.

## Accessing Jira

Once the Google Cloud Infrastructure Manager deployment completes successfully, check the **Outputs** tab of your deployment in the Infrastructure Manager console. You will find the `cloud_run_service_url`. Access this URL in your browser to begin the Jira setup process.
Due to `JIRA_HOME` being on Filestore, the Cloud Run service is configured with `max_instances = 1` to ensure data integrity for standard Jira Software.

## Terraform Outputs

The following outputs will be displayed in the Infrastructure Manager console after a successful deployment:
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
