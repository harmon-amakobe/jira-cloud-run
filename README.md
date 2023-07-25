# Deploy Jira on GCP Using Cloud Run

This is a simple containerized setup designed to utilize Cloud Run, Cloud Build, Google Storage and Cloud SQL to run Jira Data Center using the official Docker image from Atlassian.

The image is found here: <https://hub.docker.com/r/atlassian/jira-software>

## Quick Procedure Summary

1. Pull image from Docker
1. Mount folder in bucket as a volume
1. Connect to Cloud SQL instance
1. Build modified image using Cloud Build
1. Test on Cloud Run

## Repository Contents

### Dockerfile

This file defines the Docker image for your Jira Data Center application. It should be placed at the root of your repository.

### cloudbuild.yaml

This file is used to define the build steps for Google Cloud Build. Place it at the root of your repository. The cloudbuild.yaml file will specify how to build the Docker image and push it to Container Registry.

### scripts/ (Optional)

This directory stores any custom scripts or helper files that are needed during the build or deployment process. For example, when you need to set up the initial configuration for Jira Data Center or to retrieve credentials from Google Cloud Secret Manager.

### configurations/ (Optional)

This directory holds various configuration files needed by your Jira Data Center instances. For example, when you need to have a "server.xml" file to customize the Tomcat server settings or any other Jira-specific configuration files.
