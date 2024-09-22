#!/bin/bash

# Input Variables
GITHUB_LINK=$1  # GitHub repository link
CONTAINER_NAME=$2  # Name of the Node.js server container
SERVER_PORT=$3  # Internal port where the server listens (e.g., 3000)
PORT=$4  # Port to expose on the host machine

# Environment Variables (provided as a block of text)
ENV_VARS=$5             # Block of environment variables (key=value pairs)

DOMAIN="$CONTAINER_NAME.collegestorehub.com"  # Domain name based on container name
DEPLOY_FOLDER="auto_deploy_server"  # Folder to store all server clones

# Check if all arguments are provided
if [ -z "$GITHUB_LINK" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$SERVER_PORT" ] || [ -z "$PORT" ]; then
    echo "Usage: ./auto_deploy_server.sh <github_link> <container_name> <server_port> <port>"
    exit 1
fi

# Create the auto_deploy_server folder if it doesn't exist
echo "Creating folder $DEPLOY_FOLDER to store the project"
mkdir -p $DEPLOY_FOLDER

# Step 1: Clone the GitHub repository into the auto_deploy_server folder
echo "Cloning the GitHub repository: $GITHUB_LINK into $DEPLOY_FOLDER/$CONTAINER_NAME"
git clone $GITHUB_LINK $DEPLOY_FOLDER/$CONTAINER_NAME

# Step 2: Copy the Dockerfile into the project folder if it exists in the root directory
if [ -f "Dockerfile" ]; then
    echo "Copying Dockerfile to the project folder"
    cp Dockerfile $DEPLOY_FOLDER/$CONTAINER_NAME/Dockerfile
fi


# Step 3: Navigate into the project folder
cd $DEPLOY_FOLDER/$CONTAINER_NAME || exit

# Create or update the .env file
if [ -f ".env" ]; then
    echo "Existing .env file found. Skipping overwriting of the file."
else
    echo "Creating a new .env file from provided environment variables."
    echo "$ENV_VARS" > .env
fi

# Step 4: Build the Docker image
echo "Building the Docker image for $CONTAINER_NAME"
docker build -t $CONTAINER_NAME .

# Step 5: Run the Docker container, exposing the desired port
echo "Running the Docker container $CONTAINER_NAME and exposing port $PORT"
docker run -d --name $CONTAINER_NAME -p $PORT:$SERVER_PORT $CONTAINER_NAME

# Step 6: Create the NGINX configuration file
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
echo "Creating NGINX configuration for $DOMAIN"

sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 80;
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

# Step 7: Enable the site by creating a symlink to sites-enabled
echo "Enabling NGINX site for $DOMAIN"
sudo ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/

# Step 8: Restart NGINX to apply the changes
echo "Restarting NGINX"
sudo systemctl restart nginx

# Step 9: Obtain SSL certificates using Certbot
echo "Obtaining SSL certificates for $DOMAIN"
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN

# Step 10: Output success message
echo "Node.js server container '$CONTAINER_NAME' is running and accessible at http://$DOMAIN"
