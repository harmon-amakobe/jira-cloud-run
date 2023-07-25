# Use the official Atlassian Jira Software Docker image as the base image
FROM atlassian/jira-software

# Set environment variables for connecting to Cloud SQL
ENV DB_DRIVER=com.mysql.jdbc.Driver \
    DB_TYPE=mysql \
    DB_HOST=<CLOUD_SQL_INSTANCE_CONNECTION_NAME> \
    DB_PORT=<CLOUD_SQL_DATABASE_PORT> \
    DB_NAME=<JIRA_DATABASE_NAME> \
    DB_USER=<DATABASE_USER> \
    DB_PASS=<DATABASE_PASSWORD>

# Set the shared home directory to a path within the container
ENV JIRA_SHARED_HOME=/var/atlassian/application-data/jira

# Expose the port on which Jira listens (default is 8080)
EXPOSE 8080

# Add any custom configurations or files to the image
# For example, if you have custom server.xml or other Jira-specific configuration files, add them here.
# COPY configurations/server.xml /path/to/server.xml

# Start Jira using the entrypoint from the base image
CMD ["/entrypoint.sh", "-fg"]
