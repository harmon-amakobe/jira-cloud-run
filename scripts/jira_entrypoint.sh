#!/usr/bin/env bash
set -eo pipefail

# Create mount directory for JIRA_HOME
mkdir -p $JIRA_SHARED_HOME

echo "Mounting GCS Fuse for JIRA_HOME."
gcsfuse --debug_gcs --debug_fuse $_JIRA_HOME_BUCKET $JIRA_SHARED_HOME
echo "Mounting completed."

# Set up clustering configuration properties
CLUSTERED="true"
JIRA_NODE_ID="${_JIRA_NODE_ID:-jira_node_}"
EHCACHE_PEER_DISCOVERY="${_EHCACHE_PEER_DISCOVERY:-default}"
EHCACHE_LISTENER_HOSTNAME="${_EHCACHE_LISTENER_HOSTNAME:-NONE}"
EHCACHE_LISTENER_PORT="${_EHCACHE_LISTENER_PORT:-40001}"
EHCACHE_OBJECT_PORT="${_EHCACHE_OBJECT_PORT:-dynamic}"
EHCACHE_LISTENER_SOCKETTIMEOUTMILLIS="${_EHCACHE_LISTENER_SOCKETTIMEOUTMILLIS:-2000}"
EHCACHE_MULTICAST_ADDRESS="${_EHCACHE_MULTICAST_ADDRESS:-NONE}"
EHCACHE_MULTICAST_PORT="${_EHCACHE_MULTICAST_PORT:-NONE}"
EHCACHE_MULTICAST_TIMETOLIVE="${_EHCACHE_MULTICAST_TIMETOLIVE:-NONE}"
EHCACHE_MULTICAST_HOSTNAME="${_EHCACHE_MULTICAST_HOSTNAME:-NONE}"

# Start Jira Data Center with the shared home volume and clustering configuration
exec /opt/atlassian/jira/bin/start-jira.sh -fg \
    -Datlassian.plugins.enable.wait=300 \
    -Datlassian.clustered="$CLUSTERED" \
    -Datlassian.node.id="$JIRA_NODE_ID" \
    -Datlassian.shared.home="$JIRA_SHARED_HOME" \
    -Datlassian.cluster.ehcache.peer.discovery="$EHCACHE_PEER_DISCOVERY" \
    -Datlassian.cluster.ehcache.listener.hostname="$EHCACHE_LISTENER_HOSTNAME" \
    -Datlassian.cluster.ehcache.listener.port="$EHCACHE_LISTENER_PORT" \
    -Datlassian.cluster.ehcache.object.port="$EHCACHE_OBJECT_PORT" \
    -Datlassian.cluster.ehcache.listener.sockettimeoutmillis="$EHCACHE_LISTENER_SOCKETTIMEOUTMILLIS" \
    -Datlassian.cluster.ehcache.multicast.address="$EHCACHE_MULTICAST_ADDRESS" \
    -Datlassian.cluster.ehcache.multicast.port="$EHCACHE_MULTICAST_PORT" \
    -Datlassian.cluster.ehcache.multicast.timetolive="$EHCACHE_MULTICAST_TIMETOLIVE" \
    -Datlassian.cluster.ehcache.multicast.hostname="$EHCACHE_MULTICAST_HOSTNAME"
    
