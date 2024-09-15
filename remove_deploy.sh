#!/bin/bash

# Input Variables
CONTAINER_NAME=$1  # Name of the Docker container
DOMAIN="$CONTAINER_NAME.collegestorehub.com"  # Domain for the container

# Check if the container name is provided
if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: ./cleanup_docker_nginx.sh <container_name>"
    exit 1
fi

# Step 1: Stop and remove the Docker container
echo "Stopping and removing Docker container: $CONTAINER_NAME"
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME

# Step 2: Remove the NGINX configuration files
NGINX_CONF_AVAILABLE="/etc/nginx/sites-available/$DOMAIN.conf"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled/$DOMAIN.conf"

if [ -f "$NGINX_CONF_AVAILABLE" ]; then
    echo "Removing NGINX config file from sites-available: $NGINX_CONF_AVAILABLE"
    sudo rm "$NGINX_CONF_AVAILABLE"
else
    echo "NGINX config file in sites-available does not exist: $NGINX_CONF_AVAILABLE"
fi

if [ -f "$NGINX_CONF_ENABLED" ]; then
    echo "Removing NGINX config file from sites-enabled: $NGINX_CONF_ENABLED"
    sudo rm -r "$NGINX_CONF_ENABLED"
else
    echo "NGINX config file in sites-enabled does not exist: $NGINX_CONF_ENABLED"
fi

# Step 3: Restart NGINX to apply the changes
echo "Restarting NGINX"
sudo systemctl restart nginx

# Step 4: Optional - Remove any files related to the container (if applicable)
APP_DIR="./$CONTAINER_NAME"  # Assuming you cloned the app in a local 'app' directory, adjust if different
if [ -d "$APP_DIR" ]; then
    echo "Removing application files from: $APP_DIR"
    sudo rm -rf "$APP_DIR"
else
    echo "Application files not found in: $APP_DIR"
fi

# Output success message
echo "Cleanup completed for container: $CONTAINER_NAME"
