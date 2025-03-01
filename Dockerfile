FROM node:16 as builder

WORKDIR /usr/src/app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --only=production

# Copy the rest of your application code
COPY . .

# Stage: Test the application startup
# Note: This runs `npm start` for a short period and then kills it.
# Adjust the timeout as necessary.
RUN npm install -g timeout && timeout 10s npm start || (echo "npm start failed" && exit 1)

# Final image
FROM node:16

WORKDIR /usr/src/app
COPY --from=builder /usr/src/app ./

EXPOSE 3001

CMD ["npm", "start"]
