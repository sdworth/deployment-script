#!/bin/bash

BACKGROUND_COLOR="\e[45m"
TEXT_COLOR="\e[97m"
END_COLOR="\e[0m"
DYNAMODB_TABLE_NAME="checkins"

say () {
 printf "\n${BACKGROUND_COLOR}${TEXT_COLOR}~ $1 ~${END_COLOR}"
}

say "creating iam roles..."
aws iam create-role \
  --role-name lambda-read \
  --assume-role-policy-document file://scripts/policies/lambda-trust-policy.json
  > /dev/null

aws iam create-role \
  --role-name lambda-read+write \
  --assume-role-policy-document file://scripts/policies/lambda-trust-policy.json
  > /dev/null

aws iam put-role-policy \
  --role-name lambda-read \
  --policy-name dynamodb-read \
  --policy-document file://scripts/policies/dynamodb-read.json \
  > /dev/null

aws iam put-role-policy \
  --role-name lambda-read+write \
  --policy-name dynamodb-read+write \
  --policy-document file://scripts/policies/dynamodb-read-write.json \
  > /dev/null

aws iam put-role-policy \
  --role-name lambda-read \
  --policy-name logs \
  --policy-document file://scripts/policies/logs.json \
  > /dev/null

aws iam put-role-policy \
  --role-name lambda-read+write \
  --policy-name logs \
  --policy-document file://scripts/policies/logs.json \
  > /dev/null

if aws dynamodb describe-table --table-name $DYNAMODB_TABLE_NAME &> /dev/null; then
  say "using existing checkins DynamoDB table..."
else
  say "creating checkins DynamoDB table..."

  aws dynamodb create-table \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --table-name $DYNAMODB_TABLE_NAME \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    > /dev/null
fi

if aws dynamodb describe-table --table-name $DYNAMODB_TABLE_NAME &> /dev/null; then
  say "confirmed dynamodb creation succeeded"
else
  say "did not successfully create dynamodb table, exiting"
  exit 0
fi

say "running npm build"
npm run build > /dev/null

say "zipping lambda files"
if [ -f function.zip ]; then
  rm function.zip
fi

mv dist/index.js index.js
zip -r function.zip index.js node_modules > /dev/null
mv index.js dist/index.js

say "creating lambdas..."
aws lambda create-function \
  --function-name checkins-backend \
  --runtime nodejs20.x \
  --zip-file fileb://function.zip \
  --handler index.backend \
  --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-read \
  --environment Variables={DYNAMO_TABLE_NAME=$DYNAMODB_TABLE_NAME} \
  > /dev/null

aws lambda create-function \
  --function-name create-checkin \
  --runtime nodejs20.x \
  --zip-file fileb://function.zip \
  --handler index.checkins \
  --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-read+write \
  --environment Variables={DYNAMO_TABLE_NAME=$DYNAMODB_TABLE_NAME} \
  > /dev/null