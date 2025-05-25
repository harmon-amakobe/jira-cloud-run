# Setting up MySQL on Google Cloud SQL for Jira

## 1. Introduction

This document provides a step-by-step guide to setting up a MySQL database instance on Google Cloud SQL, specifically configured for use with a Jira deployment. Following these instructions will ensure your Jira instance has a robust and scalable database backend.

## 2. Prerequisites

Before you begin, ensure you have the following:

*   **A Google Cloud Project:** You need an active Google Cloud Project where you have permissions to create and manage Cloud SQL instances.
*   **`gcloud` CLI installed and configured (Optional):** The Google Cloud Command Line Interface (`gcloud`) can be used for some operations, particularly connecting to the instance. However, most steps can be performed via the Google Cloud Console. If you plan to use `gcloud`, ensure it's [installed](https://cloud.google.com/sdk/docs/install) and [initialized](https://cloud.google.com/sdk/docs/initializing).

## 3. Creating the Cloud SQL Instance

Follow these steps to create your PostgreSQL instance using the Google Cloud Console:

1.  **Navigate to Cloud SQL:** In the Google Cloud Console, use the navigation menu to go to "SQL" (under Storage or Databases).
2.  **Create Instance:** Click the "Create Instance" button.
3.  **Choose MySQL:** Select "Choose MySQL" as your database engine.
4.  **Instance ID:** Enter a unique "Instance ID" for your database (e.g., `jira-mysql-instance`). This will be part of its connection name.
5.  **Password:** Set a strong root password for the `root` user (e.g., `root@%`). Store this securely, though we will create a separate user for Jira later.
6.  **Region:** Choose a "Region" for your instance. **It is highly recommended to select the same region where your Jira application (e.g., running on Cloud Run or GKE) will be deployed** to minimize latency.
7.  **Database version:** Select a MySQL version. Jira typically supports recent versions. **MySQL 8.0 is recommended.**
8.  **Presets:** For "Presets," you can choose "Development" for testing or "Production" for live environments. This will influence default settings like machine type and HA.
9.  **Machine Type:**
    *   Select an appropriate "Machine type." For initial setups or smaller Jira instances, `db-custom-1-3840` (1 vCPU, 3.75 GB RAM) or `db-n1-standard-1` can be a good starting point.
    *   For production environments, monitor Jira's performance and adjust the machine type as needed.
10. **Storage:**
    *   **Storage type:** Choose "SSD" for optimal performance.
    *   **Storage capacity:** Start with a reasonable initial size (e.g., 20 GB or 50 GB).
    *   **Enable automatic storage increases:** Check this box to allow the storage to grow automatically as needed, preventing downtime due to full disks.
11. **Connectivity:** This is a crucial step.
    *   **Public IP vs. Private IP:**
        *   **Public IP:** Assigns a publicly accessible IP address to your instance. Access is controlled via "Authorized Networks." This is simpler for initial setup but less secure if not properly restricted.
        *   **Private IP:** Assigns an IP address within a Virtual Private Cloud (VPC) network in your project. This is more secure as the database is not exposed to the public internet. It typically requires your Jira application to be within the same VPC or connected via a Serverless VPC Access connector (if Jira is on Cloud Run).
    *   **Configuring Authorized Networks (if using Public IP):**
        *   Under "Connectivity," if you've chosen "Public IP," expand the "Networking" section.
        *   Click "Add a network."
        *   To allow access from any IP address for initial testing (e.g., connecting from your local machine with `mysql` or Cloud Shell), you can enter `0.0.0.0/0`. **WARNING: This is insecure for production environments. Replace this with the specific IP addresses or ranges of your Jira application servers or your own static IP once testing is complete.**
        *   If your Jira application will run on services like Cloud Run, you might need to find its egress IP addresses or use a Private IP setup.
    *   **Private IP and Serverless VPC Access:**
        *   If you choose "Private IP," you'll need to select a VPC network.
        *   For services like Cloud Run to connect to a Private IP Cloud SQL instance, you'll need to set up a [Serverless VPC Access connector](https://cloud.google.com/vpc/docs/serverless-vpc-access).
12. **Backups:**
    *   Under the "Data Protection" section (or "Backups" depending on the console version), **ensure "Enable automated backups" is checked.**
    *   Configure a backup window that suits your operational needs. Point-in-time recovery (PITR) is also highly recommended and enabled by default if you enable automated backups.
13. **Create Instance:** Review your settings and click "Create Instance." Provisioning can take several minutes.

## 4. Creating the Jira Database

Once your Cloud SQL instance is running, you need to create a dedicated database for Jira.

1.  **Connect to the Instance:**
    *   **Using Cloud Shell (`gcloud`):**
        1.  Open Cloud Shell from the Google Cloud Console.
        2.  Get your instance connection name from the Cloud SQL instance overview page (e.g., `your-project-id:your-region:your-instance-id`).
        3.  Run: `gcloud sql connect your-instance-id --user=root --project=your-project-id`
        4.  Enter the `root` user password you set during instance creation.
    *   **Using a local `mysql` client (if Public IP is configured and your IP is authorized):**
        1.  Get the Public IP address of your Cloud SQL instance from its overview page.
        2.  Run: `mysql --host=INSTANCE_PUBLIC_IP --user=root --password`
        3.  Enter the `root` user password when prompted.
        *Note: For production, always ensure SSL is properly configured for connections.*

2.  **SQL Command to Create Database:**
    Execute the following SQL command in the `mysql` prompt:

    ```sql
    CREATE DATABASE jiradb CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
    ```
    This command creates a database named `jiradb` with the recommended character set and collation settings for Jira with MySQL.

## 5. Creating the Jira Database User

Next, create a dedicated user for Jira to access this database.

1.  **SQL Command to Create User:**
    While still connected to your instance via `mysql` (as the `root` user), execute:

    ```sql
    CREATE USER 'jiradbuser'@'%' IDENTIFIED BY 'your-secure-password-here';
    ```
    **Important:** Replace `'your-secure-password-here'` with a strong, unique password. Store this password securely as it will be needed for your Jira configuration.

2.  **SQL Command to Grant Privileges:**
    Grant the new user full privileges on the `jiradb` database:

    ```sql
    GRANT ALL PRIVILEGES ON jiradb.* TO 'jiradbuser'@'%';
    FLUSH PRIVILEGES;
    ```

3.  **Exit `mysql`:** You can type `exit` or `\q` to exit the `mysql` prompt.

## 6. Required Connection Information

Once the above steps are completed, you will have the following information needed to configure Jira to connect to this database:

*   **`DB_HOST`**:
    *   If using **Public IP**: This is the "Public IP address" shown on your Cloud SQL instance's overview page.
    *   If using **Private IP** with the **Cloud SQL Proxy**: This will be `127.0.0.1` (as the proxy runs locally).
    *   If using **Private IP** directly from within the same VPC: This is the "Private IP address" of the instance.
*   **`DB_PORT`**: `3306` (the default MySQL port).
*   **`DB_NAME`**: `jiradb` (or the name you chose in step 4).
*   **`DB_USER`**: `jiradbuser` (or the username you chose in step 5).
*   **`DB_PASSWORD`**: The secure password you set for `jiradbuser` in step 5.
*   **`CLOUD_SQL_INSTANCE_CONNECTION_NAME`**: (Primarily for Cloud SQL Proxy when using `gcloud run deploy`) This is found on the Cloud SQL instance's overview page in the format `your-project-id:your-region:your-instance-id`. The Cloud Run deployment uses this to automatically configure the Cloud SQL Auth Proxy.

Keep this information readily available for when you deploy and configure your Jira application.
