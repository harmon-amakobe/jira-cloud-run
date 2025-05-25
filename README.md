# Jira on Cloud Run with Cloud SQL (MySQL) and GCS Attachments

## 1. Overview

This project provides a solution for deploying Atlassian Jira Software (Data Center or Server, non-clustered) on Google Cloud Run, leveraging Cloud SQL for MySQL as its database and Google Cloud Storage (GCS) for managing Jira attachments. This setup aims to provide a scalable, manageable, and cost-effective way to run Jira in the Google Cloud ecosystem.

Key features:
*   **Jira on Cloud Run:** Run Jira in a serverless, containerized environment.
*   **Cloud SQL for Database:** Utilize a managed MySQL instance for robust database performance and reliability.
*   **GCS for Attachments:** Offload Jira attachments to Google Cloud Storage for scalability and durability.
*   **Customizable Entrypoint:** A custom script handles pre-startup configuration like `dbconfig.xml` generation and GCS attachment synchronization.

## 2. Architecture Summary

The architecture consists of three main Google Cloud components:

*   **Google Cloud Run:** Hosts the Jira application, packaged as a Docker container. Cloud Run manages the serving infrastructure, scaling (though limited to a single instance for this Jira setup), and request handling.
*   **Google Cloud SQL (MySQL):** Provides a fully managed relational database service. Jira's application data (issues, workflows, users, etc.) is stored here. The Cloud Run service connects to Cloud SQL via the Cloud SQL Auth Proxy, which is automatically configured when using the `--add-cloudsql-instances` flag during deployment.
*   **Google Cloud Storage (GCS):** Used to store all file attachments uploaded to Jira issues. The custom entrypoint script synchronizes these attachments between the Jira instance and the GCS bucket at startup.

This separation of concerns allows for independent scaling and management of the application, database, and file storage.

## 3. Prerequisites

Before you begin, ensure you have the following:

*   **Google Cloud Project:** An active GCP project with billing enabled.
*   **`gcloud` CLI:** The [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and configured (run `gcloud auth login` and `gcloud config set project YOUR_PROJECT_ID`).
*   **Docker:** Docker installed and running on your local machine for building the container image.
*   **Jira Software License:** A valid license key for Jira Software (Data Center or Server).
*   **Basic understanding of Docker and Google Cloud Platform.**

## 4. Setup Steps

Follow these steps in order to deploy Jira:

1.  **Set up MySQL on Cloud SQL:**
    *   Instructions: [`CLOUD_SQL_SETUP.md`](./CLOUD_SQL_SETUP.md)
    *   This will guide you through creating a managed MySQL instance for your Jira database.

2.  **Set up Google Cloud Storage (GCS) for Attachments:**
    *   Instructions: [`GCS_BUCKET_SETUP.md`](./GCS_BUCKET_SETUP.md)
    *   This will help you create a GCS bucket to store Jira attachments and configure permissions.

3.  **Build and Deploy Jira to Cloud Run:**
    *   Instructions: [`CLOUD_RUN_DEPLOYMENT.md`](./CLOUD_RUN_DEPLOYMENT.md)
    *   This document covers building the custom Jira Docker image, pushing it to a container registry (GCR or Artifact Registry), and deploying it to Cloud Run with the necessary configurations.

## 5. Key Files

*   **`Dockerfile`**:
    *   Defines the Docker image for running Jira. It starts from the official `atlassian/jira-software` base image, installs necessary tools (`google-cloud-sdk` for GCS interaction, `default-mysql-client` for potential database operations), copies the custom `startup_scripts/` directory into the image, and sets the `ENTRYPOINT` to the `custom_entrypoint.sh` script.
*   **`startup_scripts/custom_entrypoint.sh`**:
    *   This shell script runs when the Docker container starts, before the main Jira application. Its primary responsibilities include:
        *   Validating that all required environment variables are set.
        *   Generating the `dbconfig.xml` file (if database variables are provided) within the `JIRA_HOME` directory, which Jira uses to connect to its database.
        *   Synchronizing Jira attachments from the configured GCS bucket to the local `JIRA_HOME/data/attachments` directory using `gsutil rsync`.
        *   Removing any existing Jira lock file.
        *   Finally, executing the original Jira entrypoint script (`/entrypoint.sh`) to start the Jira application.

## 6. Core Environment Variables

When deploying to Cloud Run, these are the most critical environment variables you'll need to set. Refer to `CLOUD_RUN_DEPLOYMENT.md` for a complete list and detailed explanations, including how to use Secret Manager for sensitive values.

*   `DB_HOST`: Database host (usually `127.0.0.1` when using the Cloud SQL Proxy via `--add-cloudsql-instances`).
*   `DB_PORT`: Database port (usually `3306` for MySQL).
*   `DB_NAME`: Name of the Jira database in Cloud SQL (e.g., `jiradb`).
*   `DB_USER`: Username for the Jira database user (e.g., `jiradbuser`).
*   `DB_PASSWORD`: Password for the Jira database user (strongly recommended to manage via Google Cloud Secret Manager).
*   `GCS_BUCKET_NAME`: The globally unique name of your GCS bucket for attachments.
*   `YOUR_CLOUD_SQL_INSTANCE_CONNECTION_NAME` (used in `gcloud run deploy` command): The connection name of your Cloud SQL instance (e.g., `YOUR_PROJECT_ID:YOUR_REGION:YOUR_SQL_INSTANCE_ID`).
*   `JIRA_LICENSE_KEY`: Your Jira Software license key.

## 7. Using Jira

Once deployed, you can access your Jira instance via the URL provided by Cloud Run at the end of the deployment process.
*   If it's a new installation, you will be guided through the Jira setup wizard. Choose "I'll set it up myself." The database configuration should be automatically picked up from the `dbconfig.xml` created by the entrypoint script.
*   Provide your Jira license key when prompted.
*   Complete the remaining setup steps (administrator account, etc.).
*   Subsequent access will take you directly to your Jira dashboard.

## 8. Limitations & Considerations

*   **Single-Node Jira Only:** This solution is designed for a single Jira instance. Cloud Run's `--max-instances` should be set to `1`. This setup does **not** support Jira Data Center clustering features out-of-the-box. Running multiple instances that share a common `JIRA_HOME` (especially with the default ephemeral filesystem for parts of `JIRA_HOME`) can lead to data corruption.
*   **`JIRA_HOME` Performance & Persistence:**
    *   **Attachments:** Persisted in Google Cloud Storage, which is scalable and durable.
    *   **Other `JIRA_HOME` Data (Indexes, Caches, Plugins, Logos, etc.):** By default, these reside on the Cloud Run instance's ephemeral filesystem. This means this data can be lost if the instance restarts, potentially leading to longer startup times as caches are rebuilt or plugins are reinstalled (if not baked into the image or re-downloaded).
    *   **For Production:** For production environments requiring high uptime and performance for all `JIRA_HOME` components (not just attachments), consider advanced solutions like mounting a Google Cloud Filestore (NFS) instance to Cloud Run for the entire `JIRA_HOME` directory. This is a more complex setup and is not covered in the basic deployment guide but is a key consideration for production workloads.
*   **Jira Backup Strategy:**
    *   **Database:** Cloud SQL for MySQL provides automated daily backups and point-in-time recovery (PITR). These are crucial and should be configured according to your RPO/RTO needs.
    *   **Attachments:** Google Cloud Storage offers features like object versioning, which can act as a backup for your attachments. You can also configure bucket replication to another region for disaster recovery.
    *   **Jira Native XML Backups:** For a complete application-level backup (configuration, users, projects, but excluding attachments if stored externally as configured here), Jira's built-in XML backup utility can still be used. This would typically involve `exec`-ing into the running container or setting up a scheduled job within the container (more complex) to generate the backup and then copy it to GCS. This strategy is complementary to database and attachment backups and useful for migrations or major version upgrades.

This setup provides a good balance of serverless convenience and robust managed services for running Jira on Google Cloud. Always tailor configurations and operational strategies to your specific organizational needs and risk tolerance.
