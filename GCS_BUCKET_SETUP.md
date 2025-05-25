# Setting up Google Cloud Storage (GCS) for Jira Attachments

## 1. Introduction

This guide provides instructions on how to set up a Google Cloud Storage (GCS) bucket. This bucket will be used by your Jira instance to store and manage file attachments associated with Jira issues, providing a scalable and durable storage solution.

## 2. Prerequisites

Before you begin, ensure you have the following:

*   **A Google Cloud Project:** You need an active Google Cloud Project where you have permissions to create and manage GCS buckets and IAM policies.

## 3. Creating the GCS Bucket

Follow these steps to create your GCS bucket using the Google Cloud Console:

1.  **Navigate to Cloud Storage:** In the Google Cloud Console, use the navigation menu to go to "Cloud Storage" > "Buckets."
2.  **Create Bucket:** Click the "Create bucket" button.
3.  **Name your bucket:**
    *   Enter a **globally unique name** for your bucket (e.g., `your-company-jira-attachments`). GCS bucket names must be unique across all of Google Cloud.
    *   Note this name down, as it will be needed for Jira configuration (`GCS_BUCKET_NAME`).
4.  **Choose where to store your data (Location type and Location):**
    *   **Location type:** Select "Region." This ensures your data is stored in a specific geographic location, offering lower latency for services within the same region.
    *   **Location:** Choose the **same region where your Jira application (e.g., running on Cloud Run) and your Cloud SQL instance are deployed.** This is critical for performance and to minimize cross-region data transfer costs.
5.  **Choose a default storage class for your data:**
    *   Select "Standard" storage. This is recommended for frequently accessed data like Jira attachments.
6.  **Choose how to control access to objects:**
    *   Select "Uniform" for "Access control." This ensures consistent permissions across all objects in the bucket, managed by IAM.
7.  **Optional: Protect object data (Data protection):**
    *   You can consider enabling features like "Object versioning" to keep previous versions of attachments or "Retention policy" if you have specific data lifecycle requirements. For a standard Jira setup, these are often not immediately necessary but can be configured based on your organization's policies.
8.  **Create:** Click "Create." Confirm any choices if prompted.

## 4. Configuring IAM Permissions

For your Jira application (assumed to be running on Cloud Run) to read from and write to this bucket, its service account needs appropriate permissions.

1.  **Identify your Cloud Run Service Account:**
    *   If your Jira application is deployed on Cloud Run:
        *   Navigate to your Jira service in the Cloud Run section of the Google Cloud Console.
        *   Go to the "Security" or "Identity" tab (the exact name might vary slightly).
        *   You will find the **service account email** listed there. It typically looks like `PROJECT_NUMBER-compute@developer.gserviceaccount.com` (default Compute Engine service account) or a custom service account if you configured one (e.g., `your-jira-service-account@your-project-id.iam.gserviceaccount.com`).
    *   If you are using a different service for Jira (e.g., GKE), identify the service account used by your Jira pods/nodes.

2.  **Grant Permissions to the Service Account:**
    *   Navigate back to "Cloud Storage" > "Buckets" in the Google Cloud Console.
    *   Click on the name of the bucket you just created.
    *   Go to the **"Permissions"** tab.
    *   Under "View by Principals," click the **"Grant Access"** button.
    *   In the "New principals" field, paste the service account email you identified in the previous step.
    *   In the "Assign roles" dropdown, select the role **"Storage Object Admin"** (its identifier is `roles/storage.objectAdmin`). This role provides full control over objects within the bucket (create, read, update, delete).
    *   Click **"Save."**

    This ensures that your Jira application has the necessary rights to manage attachments in the bucket.

## 5. Required Information for Jira Configuration

After setting up the GCS bucket and configuring its permissions, you will need the following information for your Jira application's environment configuration:

*   **`GCS_BUCKET_NAME`**: This is the **globally unique name** you assigned to your GCS bucket in Step 3 (e.g., `your-company-jira-attachments`).

Your Jira application's custom entrypoint script (`custom_entrypoint.sh`) will use this environment variable to know where to synchronize attachments. Ensure this variable is correctly set in the environment where your Jira application is running.
