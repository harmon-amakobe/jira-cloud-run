# Deploy Jira on GCP Using Cloud Run

This guide will walk you through the process of deploying Jira Data Center on Google Cloud Platform (GCP) using Cloud Run. This setup utilizes Google Cloud services such as Cloud Run, Cloud Build, Google Cloud Storage, and Cloud SQL. We'll be using the official Atlassian Jira Software Docker image available at [Docker Hub](https://hub.docker.com/r/atlassian/jira-software).

## Quick Procedure Summary

Follow these steps to deploy Jira Data Center on GCP:

1. Set up necessary environment variables and secrets.
2. Pull the Jira Data Center Docker image from Docker Hub.
3. Mount a folder in a bucket as a volume using Google Cloud Storage FUSE.
4. Connect to your Cloud SQL instance.
5. Build a modified image using Cloud Build.
6. Deploy the modified image to Cloud Run.
7. Test the deployment on Cloud Run.

## Repository Contents

```repository
.
├── configurations/
│   ├── server.xml
│   └── other_config_files...
├── scripts/
│   └── jira_entrypoint.sh
├── cloudbuild.yaml
├── Dockerfile
├── LICENSE
└── README.md
```

In this folder tree:

- The `Dockerfile` defines the Docker image for your Jira Data Center application. Place it at the root of your repository.
- The `cloudbuild.yaml` file is used to define the build steps for Google Cloud Build. Place it at the root of your repository.
- The `scripts` directory stores any custom scripts or helper files needed during the build or deployment process. For example, you may need to set up the initial configuration for Jira Data Center or retrieve credentials from Google Cloud Secret Manager.
- The `configurations` directory holds various configuration files needed by your Jira Data Center instances. For example, you might have a `server.xml` file to customize the Tomcat server settings or any other Jira-specific configuration files.
- The `LICENSE` file holds the MIT license associated with the project.
- The `README.md` file provides the project's documentation and instructions for setup.

## Setting Up the GCP Environment

Before you start the deployment process, you need to set up the GCP environment with the required services and configurations. Follow these steps to prepare your GCP environment:

1. Enable the necessary Google Cloud services:
   - Enable Cloud Build: [Quickstart Guide](https://cloud.google.com/build/docs/build-push-docker-image)
   - Enable Cloud Run: [Preparing for Deployment](https://cloud.google.com/run/docs/quickstarts/deploy-container)
   - Enable Cloud SQL: [MySQL Quickstart](https://cloud.google.com/sql/docs/mysql/quickstart)
   - Enable Cloud Storage: [Quickstart Guide](https://cloud.google.com/storage/docs/quickstart-console)

2. Create the following substitution variables in the Cloud Build console:
   - [Set up and manage substition variables](https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values)

   - `_JIRA_HOME_BUCKET`: Your GCS bucket name for JIRA_HOME.
   - `_JIRA_NODE_ID`: Your custom Jira node

3. Set up Google Cloud Secrets:
   - [Create and manage secrets](https://cloud.google.com/secret-manager/docs/quickstart)

   Create the following secrets:

   - Secret Name: _DB_USERNAME_SECRET
     Secret Value: [Your Database Username]
     Description: [Optional description for the secret]

   - Secret Name: _DB_PASSWORD_SECRET
     Secret Value: [Your Database Password]
     Description: [Optional description for the secret]

   - Secret Name: _JDBC_URL_SECRET
     Secret Value: [Your JDBC URL]
     Description: [Optional description for the secret]

   After creating the secrets, your Secret Manager should look something like this:

   ```plaintext
   - _DB_USERNAME_SECRET
   - _DB_PASSWORD_SECRET
   - _JDBC_URL_SECRET

With the GCP environment configured and the correct files in your repository, you are ready to build and deploy Jira Data Center to Cloud Run using Cloud Build.
