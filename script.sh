#!/bin/bash

# Input Variables
GITHUB_LINK=$1  # GitHub repository link
CONTAINER_NAME=$2  # Name of the container
SERVER_PORT=$3
PORT=$4  # Port to expose
DOMAIN="$CONTAINER_NAME.collegestorehub.com"  # Domain name based on container name

# Check if all arguments are provided
if [ -z "$GITHUB_LINK" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$PORT" ]; then
    echo "Usage: ./run_node_container.sh <github_link> <container_name> <port>"
    exit 1
fi

# Step 1: Clone the GitHub repository
git clone $GITHUB_LINK $CONTAINER_NAME
cp Dockerfile ./$CONTAINER_NAME/Dockerfile
cd $CONTAINER_NAME || exit

# Step 2: Build the Docker image
docker build -t $CONTAINER_NAME .

# Step 3: Run the Docker container, exposing the desired port
docker run -d --name $CONTAINER_NAME -p $PORT:$SERVER_PORT $CONTAINER_NAME

# Step 4: Create the NGINX configuration file
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
echo "Creating NGINX configuration for $DOMAIN"

sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Step 5: Enable the site by creating a symlink to sites-enabled
sudo ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/

# Step 6: Restart NGINX to apply the changes
sudo systemctl restart nginx

# Step 7: Obtain SSL certificates using Certbot
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN

# Output success message
echo "Node.js container '$CONTAINER_NAME' is running and accessible at http://$DOMAIN"
