FROM node:16 as builder

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Set npm configuration, clear cache, and install production dependencies
RUN npm config set registry https://registry.npmjs.org/ && \
    npm set timeout=60000 && \
    npm cache clean --force && \
    npm install --only=production

# Copy the rest of your application code
COPY . .

# Test the application startup for a brief period
# Here, we use the 'timeout' command to run npm start for 10 seconds.
# If npm start fails (exit code non-zero) within that period, the build fails.
RUN apt-get update && apt-get install -y timeout && \
    timeout 10s npm start || (echo "npm start failed during build test" && exit 1)

# Final stage: create the runtime image
FROM node:16

WORKDIR /usr/src/app

# Copy the tested application from the builder stage
COPY --from=builder /usr/src/app ./

EXPOSE 3001

CMD ["npm", "start"]
