
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_ID="204034886740"
docker build  -t hcp-tf-run-task:latest .
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
docker tag hcp-tf-run-task:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/hcp-tf-run-task:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/hcp-tf-run-task:latest
