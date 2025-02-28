FROM node:16

# Set working directory inside the container
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

#testing
# Configure npm settings:
#  - Set registry (optional, you may try the replicate endpoint)
#  - Increase timeout (e.g., to 60 seconds)
#  - Clean npm cache to avoid stale data
RUN npm config set registry https://registry.npmjs.org/ && \
    npm set timeout=60000 && \
    npm cache clean --force && \
    npm install --only=production

# Copy the rest of your application code
COPY . .

# Expose the app port
EXPOSE 3001

# Start the application
CMD ["npm", "start"]
