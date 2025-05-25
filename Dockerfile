# 1. Start from atlassian/jira-software:8.20.0
FROM atlassian/jira-software:8.20.0

# 2. Switch to the root user for package installation
USER root

# 3. Install gnupg, wget, apt-transport-https, ca-certificates
RUN apt-get update && \
    apt-get install -y gnupg wget apt-transport-https ca-certificates

# 4. Import the Google Cloud public key
RUN wget -q -O - https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# 5. Add the Google Cloud SDK package repository
RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# 6. Update the package list
RUN apt-get update

# 7. Install google-cloud-sdk and default-mysql-client
RUN apt-get install -y google-cloud-sdk default-mysql-client

# 8. Create a directory /opt/atlassian/startup_scripts/
RUN mkdir -p /opt/atlassian/startup_scripts/

# 9. Copy any custom scripts
COPY startup_scripts/ /opt/atlassian/startup_scripts/

# 10. Set /opt/atlassian/startup_scripts/ as the working directory
WORKDIR /opt/atlassian/startup_scripts/

# 11. Ensure the jira user has appropriate ownership or permissions
# No specific chown needed here for /opt/atlassian/startup_scripts/ as scripts
# will be run by root or jira user depending on the entrypoint logic.
# The base image already defines the jira user and its home directory permissions.

# Clean up apt caches
RUN rm -rf /var/lib/apt/lists/*

# 12. Switch back to the jira user
USER jira

# 13. Define the entrypoint
ENTRYPOINT ["/opt/atlassian/startup_scripts/custom_entrypoint.sh"]
