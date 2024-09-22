#!/bin/bash

# Input Variables
GITHUB_LINK=$1      # GitHub repository link
PROJECT_NAME=$2     # Name of the frontend project
PORT=$3             # Port to expose for the frontend app
ENV_VARS=$4         # Block of environment variables (key=value pairs)
ROOT_DIR=$5         # Optional root directory for monorepos

DOMAIN="$PROJECT_NAME.collegestorehub.com"  # Domain name based on project name
DEPLOY_FOLDER="auto_deploy_frontend"        # Folder to store all frontend project clones

# Check if required arguments are provided
if [ -z "$GITHUB_LINK" ] || [ -z "$PROJECT_NAME" ] || [ -z "$PORT" ]; then
    echo "Usage: ./auto_deploy_frontend.sh <github_link> <project_name> <port> [<env_vars>] [<root_dir>]"
    exit 1
fi

# Create the auto_deploy_frontend folder if it doesn't exist
echo "Creating folder $DEPLOY_FOLDER to store the project"
mkdir -p $DEPLOY_FOLDER

# Step 1: Clone the GitHub repository into the auto_deploy_frontend folder
echo "Cloning the GitHub repository: $GITHUB_LINK into $DEPLOY_FOLDER/$PROJECT_NAME"
git clone $GITHUB_LINK $DEPLOY_FOLDER/$PROJECT_NAME

# Step 2: If a root directory is provided, navigate to that directory
if [ -n "$ROOT_DIR" ]; then
    echo "Monorepo root directory specified: $ROOT_DIR"
    cd $DEPLOY_FOLDER/$PROJECT_NAME/$ROOT_DIR || exit 1
else
    # Navigate to the cloned repository directory if no root directory is provided
    cd $DEPLOY_FOLDER/$PROJECT_NAME || exit 1
fi

# Step 3: Install dependencies (assumes it's a Node.js-based project like React)
if [ -f "package.json" ]; then
    echo "Installing dependencies"
    npm install
else
    echo "No package.json found. Please ensure this is a Node.js frontend project."
    exit 1
fi

# Step 4: Create or update the .env file
if [ -f ".env" ]; then
    echo "Existing .env file found. Skipping overwriting of the file."
else
    if [ ! -z "$ENV_VARS" ]; then
        echo "Writing sanitized environment variables to .env file"
        
        # Sanitize environment variables by removing spaces around '=' and then split them into lines
        echo "$ENV_VARS" | sed 's/ *= */=/g' | tr ' ' '\n' > .env
    else
        echo "No environment variables provided."
    fi
fi

# Step 5: Build the project (assumes the build script is 'npm run build')
echo "Building the project"
npm run build

# Step 6: Move the build files to /var/www/<project_name> (or any desired directory)
echo "Deploying the build files to /var/www/$PROJECT_NAME"
sudo mkdir -p /var/www/$PROJECT_NAME
sudo cp -r build/* /var/www/$PROJECT_NAME/

# Step 7: Create the NGINX configuration file
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
echo "Creating NGINX configuration for $DOMAIN"

sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$PROJECT_NAME;
    index index.html index.htm;

    location / {
        try_files \$uri /index.html;
    }
}
EOL

# Step 8: Enable the site by creating a symlink to sites-enabled
echo "Enabling NGINX site"
sudo ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/

# Step 9: Restart NGINX to apply the changes
echo "Restarting NGINX"
sudo systemctl restart nginx

# Step 10: Obtain SSL certificates using Certbot
echo "Obtaining SSL certificates"
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN

# Step 11: Output success message
echo "Frontend project '$PROJECT_NAME' is running and accessible at http://$DOMAIN"
