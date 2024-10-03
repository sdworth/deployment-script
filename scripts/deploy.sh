#!/bin/bash

if aws dynamodb describe-table --table-name checkins &> /dev/null; then
  echo "Using existing checkins DynamoDB table..."
else
  echo "Creating checkins DynamoDB table..."

  aws dynamodb create-table \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --table-name checkins \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    &> /dev/null
fi

