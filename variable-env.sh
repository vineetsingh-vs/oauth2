#!/bin/bash

# Use TARGET_ENV environment variable if set; otherwise, default to "uat"
TARGET_ENV=${TARGET_ENV:-uat}

echo "Generating .env file for environment: ${TARGET_ENV}..."

# Fetch values from Parameter Store (using --with-decryption; safe for both SecureString and standard parameters)
NODE_ENV=$(aws ssm get-parameter --name "/${TARGET_ENV}/NODE_ENV" --with-decryption --query "Parameter.Value" --output text)
SESSION_SECRET=$(aws ssm get-parameter --name "/${TARGET_ENV}/SESSION_SECRET" --with-decryption --query "Parameter.Value" --output text)
DB_USERNAME=$(aws ssm get-parameter --name "/${TARGET_ENV}/DB_USERNAME" --with-decryption --query "Parameter.Value" --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/${TARGET_ENV}/DB_PASSWORD" --with-decryption --query "Parameter.Value" --output text)
DB_HOST=$(aws ssm get-parameter --name "/${TARGET_ENV}/DB_HOST" --with-decryption --query "Parameter.Value" --output text)
DB_NAME=$(aws ssm get-parameter --name "/${TARGET_ENV}/DB_NAME" --with-decryption --query "Parameter.Value" --output text)
DIALECT=$(aws ssm get-parameter --name "/${TARGET_ENV}/DIALECT" --with-decryption --query "Parameter.Value" --output text)
echo "DEBUG: DB_HOST value from SSM: ${DB_HOST}"

# Write the .env file using a here-document
cat <<EOF > .env
NODE_ENV=${NODE_ENV}
PORT=3001
SESSION_SECRET=${SESSION_SECRET}
DATABASE_URL=postgres://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}?sslmode=require

JWT_PRIVATE_KEY_PATH=./keys/ec_private_key.pem
JWT_PUBLIC_KEY_PATH=./keys/ec_public_key.pem

DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
DB_HOST=${DB_HOST}
DIALECT=${DIALECT}
EOF

echo ".env file generated for environment: ${TARGET_ENV}"
