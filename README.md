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
   - Cloud Build
   - Cloud Run
   - Cloud SQL
   - Cloud Storage

2. Create the following environment variables in the Cloud Build console:
   - `_JIRA_HOME_BUCKET`: Your GCS bucket name for JIRA_HOME.
   - `_JIRA_NODE_ID`: Your custom Jira node ID (optional).
   - `_EHCACHE_PEER_DISCOVERY`: Set to 'automatic' or 'default' for EHCACHE peer discovery.
   - `_EHCACHE_LISTENER_HOSTNAME`: Your listener hostname (optional).
   - `_EHCACHE_LISTENER_PORT`: Port number for the listener.
   - `_EHCACHE_OBJECT_PORT`: Port number for remote objects (optional).
   - `_EHCACHE_LISTENER_SOCKETTIMEOUTMILLIS`: Listener socket timeout in milliseconds.
   - `_EHCACHE_MULTICAST_ADDRESS`: Your multicast group address (required for automatic EHCACHE peer discovery).
   - `_EHCACHE_MULTICAST_PORT`: Dedicated port for multicast heartbeat traffic (required for automatic EHCACHE peer discovery).
   - `_EHCACHE_MULTICAST_TIMETOLIVE`: Value between 0 and 255 determining packet propagation (required for automatic EHCACHE peer discovery).
   - `_EHCACHE_MULTICAST_HOSTNAME`: Hostname or IP of the interface for multicast packets (required for automatic EHCACHE peer discovery).

3. Set up Google Cloud Secrets:
   - Create secrets for the database username, password, and JDBC URL using Google Cloud Secret Manager.
   - Replace `_DB_USERNAME_SECRET`, `_DB_PASSWORD_SECRET`, and `_JDBC_URL_SECRET` in the cloudbuild.yaml file with the appropriate secret paths.

With the GCP environment configured and the correct files in your repository, you are ready to build and deploy Jira Data Center to Cloud Run using Cloud Build.
