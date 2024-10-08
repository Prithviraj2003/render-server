# Use an official Node.js runtime as a parent image
FROM node:16

# Set the working directory in the container
WORKDIR /app

RUN npm i -g pm2

# Copy package.json and package-lock.json into the container
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application files
COPY . .

# Start the app
CMD ["pm2-runtime", "start", "npm", "--name", "test_server", "--", "start"]