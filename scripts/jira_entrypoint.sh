#!/usr/bin/env bash
set -eo pipefail

# Create mount directory for JIRA_HOME
mkdir -p $JIRA_SHARED_HOME

echo "Mounting GCS Fuse for JIRA_HOME."
gcsfuse --debug_gcs --debug_fuse $_JIRA_HOME_BUCKET $JIRA_SHARED_HOME
echo "Mounting completed."

# Set database configuration as environment variables
export ATL_JDBC_URL="jdbc:mysql://google/jira?cloudSqlInstance=anza-maliza:us-central1:jira-test&socketFactory=com.google.cloud.sql.mysql.SocketFactory"
export ATL_JDBC_USER="jira"
export ATL_JDBC_PASSWORD="password"

# Start Jira Data Center with the shared home volume and clustering configuration
exec /opt/atlassian/jira/bin/start-jira.sh -fg \
    -Datlassian.plugins.enable.wait=300 \
    -Datlassian.clustered="true" \
    -Datlassian.shared.home="$JIRA_SHARED_HOME"
