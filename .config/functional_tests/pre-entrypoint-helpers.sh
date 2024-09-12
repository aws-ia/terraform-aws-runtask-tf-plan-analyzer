#!/bin/bash
## NOTE: this script runs at the start of functional test
## use this to load any configuration before the functional test
## TIPS: avoid modifying the .project_automation/functional_test/entrypoint.sh
## migrate any customization you did on entrypoint.sh to this helper script
echo "Executing Pre-Entrypoint Helpers"


#********** Project Path *************
PROJECT_PATH=${BASE_PATH}/project
PROJECT_TYPE_PATH=${BASE_PATH}/projecttype
cd ${PROJECT_PATH}

#********** TFC Env Vars *************
export AWS_DEFAULT_REGION=us-west-2
export AWS_REGION=us-west-2
export TFE_TOKEN=`aws secretsmanager get-secret-value --secret-id abp/hcp/token --region $AWS_DEFAULT_REGION | jq -r ".SecretString"`
export TF_TOKEN_app_terraform_io=`aws secretsmanager get-secret-value --secret-id abp/hcp/token --region $AWS_DEFAULT_REGION | jq -r ".SecretString"`

#********** MAKEFILE *************
echo "Build the lambda function packages"
make all

#********** Get tfvars from SSM *************
echo "Get *.tfvars from SSM parameter"
aws ssm get-parameter \
  --name "/abp/hcp/functional/terraform-aws-runtask-tf-plan-analyzer/terraform_tests.tfvars" \
  --with-decryption \
  --query "Parameter.Value" \
  --output "text" \
  --region $AWS_DEFAULT_REGION >> ./tests/terraform.auto.tfvars