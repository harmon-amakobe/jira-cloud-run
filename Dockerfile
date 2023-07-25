# Use the official Atlassian Jira Software Docker image as the base image
FROM atlassian/jira-software

# Install system dependencies
RUN set -e; \
    apt-get update -y && apt-get install -y \
    tini \
    lsb-release; \
    gcsFuseRepo=gcsfuse-`lsb_release -c -s`; \
    echo "deb http://packages.cloud.google.com/apt $gcsFuseRepo main" | \
    tee /etc/apt/sources.list.d/gcsfuse.list; \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key add -; \
    apt-get update; \
    apt-get install -y gcsfuse \
    && apt-get clean

# Set fallback mount directory (shared home)
ENV JIRA_SHARED_HOME /mnt/gcs/jira-shared

# Copy the jira_entrypoint.sh script from the scripts directory into the container
COPY scripts/jira_entrypoint.sh /app/jira_entrypoint.sh

# Ensure the script is executable
RUN chmod +x /app/jira_entrypoint.sh

# Use tini to manage zombie processes and signal forwarding
ENTRYPOINT ["/usr/bin/tini", "--"]

# Pass the startup script as arguments to Tini
CMD ["/app/jira_entrypoint.sh"]
