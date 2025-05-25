# Deploying Custom Jira to Cloud Run

## 1. Introduction

This document guides you through building your custom Jira Docker image (created using the `Dockerfile` in this repository), pushing it to a Google Cloud container registry (GCR or Artifact Registry), and deploying it as a service on Cloud Run.

### Prerequisites

Before proceeding, ensure you have completed the following:

*   **Cloud SQL for MySQL Setup:** Your MySQL instance should be ready, and you should have the database name, username, and password. Refer to `CLOUD_SQL_SETUP.md`.
*   **Google Cloud Storage (GCS) Bucket Setup:** A GCS bucket for Jira attachments must be created and accessible by your Jira service account. Refer to `GCS_BUCKET_SETUP.md`.
*   **Docker:** Docker must be installed and running on your local machine to build the image.
*   **Google Cloud SDK (`gcloud` CLI):** The `gcloud` command-line tool must be installed and authenticated. If not, install it from [here](https://cloud.google.com/sdk/docs/install) and run `gcloud auth login`.
*   **Project Configuration:** Ensure your `gcloud` CLI is configured for the correct project: `gcloud config set project YOUR_PROJECT_ID`.

**Important:** Replace all placeholders like `YOUR_PROJECT_ID`, `YOUR_REGION`, `YOUR_CLOUD_SQL_INSTANCE_CONNECTION_NAME`, etc., with your actual values.

## 2. Building the Docker Image

Navigate to the directory containing your `Dockerfile` and the `startup_scripts` directory.

Run the following command to build your Docker image:

**Option 1: Using Google Container Registry (GCR)**

```bash
docker build -t gcr.io/YOUR_PROJECT_ID/jira-cloudrun:latest .
```
Replace `YOUR_PROJECT_ID` with your Google Cloud Project ID.

**Option 2: Using Google Artifact Registry**

Artifact Registry is Google Cloud's recommended service for storing and managing container images.

First, ensure you have an Artifact Registry Docker repository created in your project. If not, create one (e.g., `jira-repo` in `YOUR_REGION`):
```bash
gcloud artifacts repositories create jira-repo \
    --repository-format=docker \
    --location=YOUR_REGION \
    --description="Jira Docker repository"
```
Replace `YOUR_REGION` with your desired region (e.g., `us-central1`).

Then, build and tag your image:
```bash
docker build -t YOUR_REGION-docker.pkg.dev/YOUR_PROJECT_ID/jira-repo/jira-cloudrun:latest .
```
Replace `YOUR_REGION`, `YOUR_PROJECT_ID`, and `jira-repo` (if you used a different name) with your actual values.

## 3. Pushing the Docker Image

After successfully building the image, you need to push it to the chosen registry.

**Option 1: Pushing to Google Container Registry (GCR)**

1.  **Configure Docker for GCR:**
    If you haven't pushed images to GCR from your machine before, you might need to configure Docker credentials:
    ```bash
    gcloud auth configure-docker
    ```
    This command configures Docker to use your `gcloud` credentials to authenticate with GCR.

2.  **Push the image:**
    ```bash
    docker push gcr.io/YOUR_PROJECT_ID/jira-cloudrun:latest
    ```

**Option 2: Pushing to Google Artifact Registry**

1.  **Configure Docker for Artifact Registry:**
    If you haven't pushed images to Artifact Registry from your machine before, configure Docker credentials for your specific region:
    ```bash
    gcloud auth configure-docker YOUR_REGION-docker.pkg.dev
    ```
    Replace `YOUR_REGION` with the region where your Artifact Registry repository is located.

2.  **Push the image:**
    ```bash
    docker push YOUR_REGION-docker.pkg.dev/YOUR_PROJECT_ID/jira-repo/jira-cloudrun:latest
    ```

## 4. Deploying to Cloud Run via `gcloud`

Use the `gcloud run deploy` command to deploy your Jira application.

**Command Structure:**

```bash
gcloud run deploy jira-service \
    --image YOUR_IMAGE_URL \
    --platform managed \
    --region YOUR_REGION \
    --project YOUR_PROJECT_ID \
    --set-env-vars="DB_HOST=127.0.0.1,DB_PORT=3306,DB_NAME=YOUR_DB_NAME,DB_USER=YOUR_DB_USER,DB_PASSWORD=YOUR_DB_PASSWORD,GCS_BUCKET_NAME=YOUR_GCS_BUCKET_NAME,JIRA_LICENSE_KEY=YOUR_JIRA_LICENSE_KEY" \
    --add-cloudsql-instances=YOUR_CLOUD_SQL_INSTANCE_CONNECTION_NAME \
    --memory=8Gi \
    --cpu=2 \
    --service-account=YOUR_SERVICE_ACCOUNT_EMAIL \
    --timeout=900s \
    --max-instances=1 \
    --allow-unauthenticated # Consider security implications
```

**Replace the following placeholders:**

*   `jira-service`: Choose a name for your Cloud Run service.
*   `YOUR_IMAGE_URL`:
    *   For GCR: `gcr.io/YOUR_PROJECT_ID/jira-cloudrun:latest`
    *   For Artifact Registry: `YOUR_REGION-docker.pkg.dev/YOUR_PROJECT_ID/jira-repo/jira-cloudrun:latest`
*   `YOUR_REGION`: The region where you want to deploy your Cloud Run service (e.g., `us-central1`). **This should ideally be the same region as your Cloud SQL instance and GCS bucket.**
*   `YOUR_PROJECT_ID`: Your Google Cloud Project ID.
*   `YOUR_DB_NAME`: The name of your Jira database (e.g., `jiradb`).
*   `YOUR_DB_USER`: The username for your Jira database (e.g., `jiradbuser`).
*   `DB_PORT`: The port number for your MySQL database (e.g., `3306`). If not set, the entrypoint script defaults to `3306`.
*   `YOUR_DB_PASSWORD`: The password for your Jira database user. **Consider using Secret Manager for sensitive values like passwords:**
    *   Store the password in Secret Manager: `gcloud secrets versions add DB_PASSWORD_SECRET --data-file="/path/to/password.txt"`
    *   Then, in `--set-env-vars`, use: `DB_PASSWORD=latest:DB_PASSWORD_SECRET`
*   `YOUR_GCS_BUCKET_NAME`: The name of your GCS bucket for attachments.
*   `YOUR_JIRA_LICENSE_KEY`: Your Jira Software license key.
*   `YOUR_CLOUD_SQL_INSTANCE_CONNECTION_NAME`: The connection name of your Cloud SQL for MySQL instance (e.g., `YOUR_PROJECT_ID:YOUR_REGION:YOUR_SQL_INSTANCE_ID`). This is found on the Cloud SQL instance's overview page. **Using this method is highly recommended as it automatically configures the Cloud SQL Proxy sidecar container.**
*   `YOUR_SERVICE_ACCOUNT_EMAIL`: The email of the service account that Cloud Run will use. This service account needs "Storage Object Admin" on the GCS bucket and typically "Cloud SQL Client" to connect to the database (though `--add-cloudsql-instances` often handles this). If you created a dedicated service account for Jira, use that. Otherwise, you might use the default Compute Engine service account (`PROJECT_NUMBER-compute@developer.gserviceaccount.com`).

**Explanation of Parameters:**

*   `--set-env-vars`: Sets the environment variables required by your `custom_entrypoint.sh` script.
    *   `DB_HOST=127.0.0.1`: When using `--add-cloudsql-instances`, the Cloud SQL Proxy runs as a sidecar, and Jira connects to it via localhost.
    *   `DB_PORT=3306`: (Example in the main command, also default in entrypoint) Set this if your MySQL instance uses a non-default port.
    *   Optional Jira proxy variables (if Jira is behind a reverse proxy and needs to know its public URL):
        *   `JIRA_PROXY_NAME=your-jira-domain.com`
        *   `JIRA_PROXY_PORT=443`
        *   `JIRA_SCHEME=https`
*   `--add-cloudsql-instances`: Connects your Cloud Run service to your Cloud SQL for MySQL instance securely. The Cloud SQL Proxy is automatically configured.
*   `--memory`: Amount of memory allocated to the instance (e.g., `8Gi`). Jira is memory-intensive.
*   `--cpu`: Number of vCPUs allocated (e.g., `2`).
*   `--service-account`: Specifies the IAM service account for the Cloud Run service.
*   `--timeout`: Maximum request processing time (e.g., `900s`). Jira operations can sometimes be lengthy.
*   `--max-instances=1`: **Crucial for non-clustered Jira Data Center.** Standard Jira Software or Jira Data Center without clustering support should run as a single instance to avoid data corruption with the `JIRA_HOME` directory.
*   `--allow-unauthenticated`: Allows public access to your Jira instance. If you want to restrict access (e.g., via IAP or internal load balancer), remove this and configure appropriate authentication methods.

## 5. Considerations for `JIRA_HOME`

The `JIRA_HOME` directory (`/var/atlassian/application-data/jira`) stores various Jira data, including plugins, indexes, caches, and attachments.

*   **Attachments:** In this setup, attachments are offloaded to Google Cloud Storage (GCS) via the `custom_entrypoint.sh` script, ensuring persistent and scalable storage for them.
*   **Other `JIRA_HOME` Data (Indexes, Caches, Plugins):**
    *   By default, the rest of the `JIRA_HOME` data (indexes, caches, installed plugins, logos, etc.) will use the Cloud Run container's ephemeral filesystem. This means if the instance is restarted or moved, this data might be lost, leading to re-indexing or re-configuration needs.
    *   **For optimal performance and data persistence for these components**, especially for production environments, you would ideally mount a persistent disk solution for `JIRA_HOME`.
        *   Google Cloud Filestore (NFS) is a possible solution and has beta support for Cloud Run. This involves setting up a Filestore instance and a Serverless VPC Access connector.
        *   This advanced setup is not covered in these primary deployment steps due to its complexity but is a key consideration for production workloads requiring high availability and performance.
    *   For now, be aware that frequent instance restarts might lead to longer startup times as caches are rebuilt or plugins reinstalled (if not baked into the image).
    *   The database connection details (e.g., `DB_NAME`, `DB_USER`) should match what you configured when setting up your Cloud SQL for MySQL instance.

## 6. Post-Deployment

1.  **Access Jira:** Once the deployment is complete, `gcloud` will output the URL for your Jira service. Open this URL in your browser.
2.  **Jira Setup Wizard:** You should be greeted by the Jira setup wizard.
    *   Choose "I'll set it up myself."
    *   Configure the database: The `dbconfig.xml` should have been created by the entrypoint script. If prompted, the details are what you provided in the environment variables.
    *   Follow the on-screen instructions to complete the setup, including providing your license key (if not pre-set via `JIRA_LICENSE_KEY` and already active).
3.  **Test Attachments:** Create an issue and try uploading and downloading an attachment to verify the GCS integration is working. Check your GCS bucket to see if the attachment appears.

## 7. Updating the Service

To update your Jira service (e.g., with a new image version containing Jira updates or script changes):

1.  Build and push your new Docker image (as described in Sections 2 and 3).
2.  Re-run the `gcloud run deploy` command from Section 4, ensuring the `--image` parameter points to your new image tag. Cloud Run will perform a rolling update.

```bash
gcloud run deploy jira-service --image YOUR_NEW_IMAGE_URL --region YOUR_REGION --project YOUR_PROJECT_ID # ... (include other relevant parameters from your initial deploy)
```

Remember to keep your environment variables and other configurations consistent unless intentionally changing them.
