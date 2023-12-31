#!/usr/bin/env bash
set -eo pipefail

# Create mount directory for JIRA_HOME
mkdir -p $JIRA_SHARED_HOME

# Redirect output to a log file
LOG_FILE="/app/jira_entrypoint.log"
exec > >(tee -a ${LOG_FILE} )
exec 2> >(tee -a ${LOG_FILE} >&2)

# Print the value of JIRA_SHARED_HOME and _JIRA_HOME_BUCKET for debugging purposes
echo "JIRA_SHARED_HOME: $JIRA_SHARED_HOME"
echo "_JIRA_HOME_BUCKET: $_JIRA_HOME_BUCKET"

echo "Mounting GCS Fuse for JIRA_HOME."
gcsfuse --debug_gcs --debug_fuse $_JIRA_HOME_BUCKET $JIRA_SHARED_HOME
echo "Mounting completed."

# Start Jira Data Center with the shared home volume and clustering configuration
exec /opt/atlassian/jira/bin/start-jira.sh -fg \
    -Datlassian.plugins.enable.wait=300 \
    -Datlassian.clustered="true" \
    -Datlassian.shared.home="$JIRA_SHARED_HOME"

# Output the log file at the end of the script execution
cat ${LOG_FILE}
