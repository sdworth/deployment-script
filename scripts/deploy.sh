#!/bin/bash

BACKGROUND_COLOR="\e[45m"
TEXT_COLOR="\e[97m"
END_COLOR="\e[0m"

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

if aws dynamodb describe-table --table-name checkins &> /dev/null; then
  say "using existing checkins DynamoDB table..."
else
  say "creating checkins DynamoDB table..."

  aws dynamodb create-table \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --table-name checkins \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    > /dev/null
fi

if aws dynamodb describe-table --table-name checkins &> /dev/null; then
  say "confirmed dynamodb creation succeeded"
else
  say "did not successfully create dynamodb table, exiting"
  exit 0
fi

say "running npm build"
npm run build

say "zipping lambda files"
if [ -f function.zip ]; then
  rm function.zip
fi

mv dist/index.js index.js
zip -r function.zip index.js node_modules > /dev/null
mv index.js dist/index.js
