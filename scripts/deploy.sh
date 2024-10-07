#!/bin/bash

BACKGROUND_COLOR="\e[45m"
TEXT_COLOR="\e[97m"
END_COLOR="\e[0m"

DYNAMODB_TABLE_NAME="checkins"
REGION_NAME="us-east-1"

say () {
 printf "\n${BACKGROUND_COLOR}${TEXT_COLOR}~ $1 ~${END_COLOR}"
}

# ----------------------------------------
# IAM Setup
# ----------------------------------------
say "creating iam roles"
aws iam create-role \
  --role-name lambda-read \
  --assume-role-policy-document file://scripts/policies/lambda-trust-policy.json \
  > /dev/null

aws iam create-role \
  --role-name lambda-read+write \
  --assume-role-policy-document file://scripts/policies/lambda-trust-policy.json \
  > /dev/null

aws iam create-role \
  --role-name scheduler-invoke \
  --assume-role-policy-document file://scripts/policies/scheduler-trust-policy.json \
  > /dev/null

say "attaching permissions to roles"
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

aws iam put-role-policy \
  --role-name scheduler-invoke \
  --policy-name lambda-invoke \
  --policy-document file://scripts/policies/lambda-invoke.json \
  > /dev/null

# ----------------------------------------
# Dynamodb Setup
# ----------------------------------------
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

# ----------------------------------------
# Building Lambda files
# ----------------------------------------
say "running npm build"
npm run build > /dev/null

say "zipping lambda files"
if [ -f function.zip ]; then
  rm function.zip
fi

mv dist/index.js index.js
zip -r function.zip index.js node_modules > /dev/null
mv index.js dist/index.js

# ----------------------------------------
# Function Setup
# ----------------------------------------
if aws lambda get-function --function-name create-checkin &> /dev/null ; then
  say "updating existing create-checkin function"
  aws lambda update-function-code \
    --function-name create-checkin \
    --zip-file fileb://function.zip \
    > /dev/null
else
  say "creating create-checkin function"
  aws lambda create-function \
    --function-name create-checkin \
    --runtime nodejs20.x \
    --zip-file fileb://function.zip \
    --handler index.checkin \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-read+write \
    --environment Variables={DYNAMO_TABLE_NAME=$DYNAMODB_TABLE_NAME} \
    > /dev/null
fi

if aws lambda get-function --function-name checkins-backend &> /dev/null ; then
  say "updating existing checkins-backend function"
  aws lambda update-function-code \
    --function-name checkins-backend \
    --zip-file fileb://function.zip \
    > /dev/null
else
  say "creating checkins-backend function"
  aws lambda create-function \
    --function-name checkins-backend \
    --runtime nodejs20.x \
    --zip-file fileb://function.zip \
    --handler index.backend \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-read \
    --environment Variables={DYNAMO_TABLE_NAME=$DYNAMODB_TABLE_NAME} \
    > /dev/null
fi

if aws lambda get-function --function-name create-checkin &> /dev/null && aws lambda get-function --function-name checkins-backend &> /dev/null ; then
  say "confirmed functions exist"
else
  say "could not confirm functions exist, exiting"
  exit 0
fi

# ----------------------------------------
# Scheduler Setup
# ----------------------------------------
if aws scheduler get-schedule --name create-checkin &> /dev/null ; then
  say "⚠️ schedule already exists -- you may need to delete and try again ⚠️"
else
  say "creating scheduler"
  aws scheduler create-schedule \
    --name create-checkin \
    --flexible-time-window Mode=OFF \
    --schedule-expression "rate(5 minutes)" \
    --target "{\"Arn\": \"arn:aws:lambda:${REGION_NAME}:${AWS_ACCOUNT_ID}:function:create-checkin\", \"RoleArn\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:role/scheduler-invoke\"}" \
    > /dev/null
fi

# ----------------------------------------
# Function URL Setup
# ----------------------------------------
say "creating function url for the backend service"
aws lambda add-permission \
    --function-name checkins-backend \
    --action lambda:InvokeFunctionUrl \
    --statement-id FunctionURLAllowPublicAccess \
    --principal "*" \
    --function-url-auth-type NONE \
    > /dev/null

say "backend url:"
printf "\n"
aws lambda create-function-url-config \
  --function-name checkins-backend \
  --auth-type NONE | grep "FunctionUrl"
