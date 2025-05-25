#!/bin/bash
set -e

echo "Custom entrypoint script is running."

# Check for required environment variables
REQUIRED_VARS=("DB_HOST" "DB_NAME" "DB_USER" "DB_PASSWORD" "GCS_BUCKET_NAME")
for VAR_NAME in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR_NAME}" ]; then
    echo "Error: Environment variable ${VAR_NAME} is not set." >&2
    exit 1
  fi
done

JIRA_HOME="/var/atlassian/application-data/jira"
DB_PORT_EFFECTIVE="${DB_PORT:-3306}"

# Create dbconfig.xml if database variables are set
if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ]; then
  echo "Configuring Jira database connection (dbconfig.xml)..."
  mkdir -p "$JIRA_HOME"
  cat <<EOF > "$JIRA_HOME/dbconfig.xml"
<?xml version="1.0" encoding="UTF-8"?>
<jira-database-config>
  <name>defaultDS</name>
  <delegator-name>default</delegator-name>
  <database-type>mysql8</database-type>
  <schema-name>public</schema-name>
  <jdbc-datasource>
    <url>jdbc:mysql://${DB_HOST}:${DB_PORT_EFFECTIVE}/${DB_NAME}?sessionVariables=sql_mode=NO_AUTO_VALUE_ON_ZERO&amp;autoReconnect=true&amp;useSSL=false</url>
    <driver-class>com.mysql.cj.jdbc.Driver</driver-class>
    <username>${DB_USER}</username>
    <password>${DB_PASSWORD}</password>
    <pool-min-size>20</pool-min-size>
    <pool-max-size>20</pool-max-size>
    <pool-max-wait>30000</pool-max-wait>
    <pool-max-idle>20</pool-max-idle>
    <pool-remove-abandoned>true</pool-remove-abandoned>
    <pool-remove-abandoned-timeout>300</pool-remove-abandoned-timeout>
    <validation-query>SELECT 1</validation-query>
    <validation-query-timeout>3</validation-query-timeout>
    <time-between-eviction-runs-millis>30000</time-between-eviction-runs-millis>
    <min-evictable-idle-time-millis>60000</min-evictable-idle-time-millis>
    <test-on-borrow>false</test-on-borrow>
    <test-while-idle>true</test-while-idle>
    <connection-properties>tcpKeepAlive=true;socketTimeout=240</connection-properties>
  </jdbc-datasource>
</jira-database-config>
EOF
  echo "Setting ownership of dbconfig.xml to jira user..."
  chown 2001:2001 "$JIRA_HOME/dbconfig.xml"
  echo "dbconfig.xml configured."
else
  echo "Skipping dbconfig.xml creation as not all database variables are set."
fi

JIRA_ATTACHMENTS_DIR="$JIRA_HOME/data/attachments"
mkdir -p "$JIRA_ATTACHMENTS_DIR"

if [ -n "$GCS_BUCKET_NAME" ]; then
  echo "Synchronizing attachments from GCS bucket: gs://${GCS_BUCKET_NAME}/attachments to ${JIRA_ATTACHMENTS_DIR}..."
  # Ensure gsutil is available and configured if needed (gcloud auth might be required if not using workload identity)
  if command -v gsutil &> /dev/null; then
    gsutil -m rsync -r "gs://${GCS_BUCKET_NAME}/attachments" "$JIRA_ATTACHMENTS_DIR"
    echo "Attachment synchronization complete."
    echo "Setting ownership of attachments directory to jira user..."
    chown -R 2001:2001 "$JIRA_ATTACHMENTS_DIR"
    echo "Attachment directory ownership set."
  else
    echo "Warning: gsutil command not found. Skipping GCS attachment synchronization." >&2
  fi
else
    echo "GCS_BUCKET_NAME not set. Skipping attachment synchronization."
fi

# Remove Jira lock file
if [ -f "$JIRA_HOME/.jira-home.lock" ]; then
  echo "Removing existing Jira lock file: $JIRA_HOME/.jira-home.lock"
  rm -f "$JIRA_HOME/.jira-home.lock"
fi

echo "Handing over to original Jira entrypoint (/entrypoint.sh)..."
exec /entrypoint.sh "$@"
