# Scripting Challenge

This repo provides a simple implementation of a deployment script to create a simple lambda-based AWS deployment from scratch.

The primary script that does this deployment is 

```
./scripts/deploy
```

## Setup directions

In order to run the deploy script from your local machine, please go through the follow steps

1. Install npm if you have not already: https://docs.npmjs.com/downloading-and-installing-node-js-and-npm

2. Install the AWS CLI:
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

3. Authenticate the CLI using [short-term credentials](https://aws.amazon.com/blogs/security/aws-single-sign-on-now-enables-command-line-interface-access-for-aws-accounts-using-corporate-credentials/)
```
$ aws configure
    # example dialogue
    # AWS Access Key ID [None]: YOUR_KEY_ID
    # AWS Secret Access Key [None]: YOUR_ACCESS_KEY
    # Default region name [None]: us-east-1
    # Default output format [None]: json
$ aws configure set aws_session_token YOUR_TOKEN_HERE
```

4. Set your [account id](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html) as an env variable
```
export AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID_HERE
```

At this point, you should be able to run the script with 
```
./scripts/deploy
```

## Methodology
This deployment script is intended to be run against a new AWS environment to deploy the environment from scratch. While there is some error handling in place to account for some set of resources already existing, it is not intended for ongoing updates of the lambda code, which could be handled more efficiently with a shorter script.

This script creates the following resources, and the IAM roles required to make them work:
* A lambda function for the checkins-backend function
* A lambda function for the create-checkin function
* A dynamodb table called "checkins"
* An eventbridge schedule that calls the create-checkins function every five minutes

The checkin-backend function is then exposed to the internet using a public function url, which can be used to view the checkins from the dynamodb table.

Lambdas were chosen for this deployment because of the straightforward functional nature of this code, as well as their relative ease of maintainability. The specific settings for this infrastructure are only intended for a test environment, and may need to be reconsidered in a true production deployment. For example, the billing mode for DynamoDB may need to be tweaked were this environment ever to get considerable traffic.

Permissions are intended to follow the principle of least privilege, giving each service access only to the resources it needs.

This deployment script is a simple monolith bash script, which is easy to create and edit for infrastructure on this size. However, for more complex needs, I would consider if a true infrastructure as code utility such as Terraform would be a better fit. 

Lastly, this script is intended to be run from a local environment. However, for production settings I would investigate integrating deployments into a CI/CD pipeline, rather than relying on direct local deployments. 

There are a few additional areas that could be improved given more time:
* The monolith script could be broken up into subscripts, allowing the deployment of individual resources as needed.
* The error handling in the script is fairly basic -- if resources already exist they are mostly ignored, and there is simple validation in place for the success of a few key resources. However, failures in the creation of resources could be handled more robustly, and in a production setting, existing resources may need to be handled more loudly.
* The resource definitions in several of the permission policies could be more specific, but left general for simplicity's sake here. 

