# Deploy Jira on GCP Using Cloud Run

This is a simple containerized setup designed to utilize Cloud Run, Cloud Build, Google Storage and Cloud SQL to run Jira Data Center using the official Docker image from Atlassian.

The image is found here: <https://hub.docker.com/r/atlassian/jira-software>

## Quick Summary:
1. Pull image from Docker
1. Mount folder in bucket as a volume
1. Connect to Cloud SQL instance
1. Build modified image using Cloud Build
1. Test on Cloud Run
