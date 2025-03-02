#!/bin/sh

echo "Generating .env file from Parameter Store..."
./variable-env.sh

echo "Downloading key files from S3..."

# Download the private key
aws s3 cp s3://maddiebuck/keys/ec_private_key.pem /usr/src/app/keys/ec_private_key.pem
# Download the public key
aws s3 cp s3://maddiebuck/keys/ec_public_key.pem /usr/src/app/keys/ec_public_key.pem

# Verify keys are downloaded
if [ ! -f /usr/src/app/keys/ec_private_key.pem ] || [ ! -f /usr/src/app/keys/ec_public_key.pem ]; then
  echo "Failed to download key files from S3. Exiting."
  exit 1
fi

echo "Running database migrations..."
npx dotenv -e .env -- npx sequelize-cli db:migrate --env prod

echo "Starting the application..."
npm start
