# HCP Terraform run task app template


### Build and test the app locally

1. Install dependencies

   * ngrok 3.6.0+
   * docker 25.0.3+

1. Build and run the docker image

    ```sh
    docker build --platform linux/amd64 -t hcp-tf-run-task:latest .
    docker run -p 9000:8080 hcp-tf-run-task:latest
    ```

1. Test the application (business logic)

    ```sh
    curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d @payload.json
    ```

    Since the payload has non-real values, you might get a response like below, this is expected

    ```json
    {"url": "", "status": "failed", "message": "HCP Terraform run task failed, please look into the logs for more details.", "results": []}
    ```

1. Temporarily expose the endpoint to test the app with HCP Terraform run task workflow

    ```sh
    ngrok http 9000
    ```

1. Once the Ngrok tunnel is up and running,
   1. Create a run task [using the docs here](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings/run-tasks#creating-a-run-task) to test out your application.
   1. Use the `http://{NGROK_URL}/2015-03-31/functions/function/invocation` as the endpoint for the run task


### Deploy the image to ECR to be later used with Terraform

1. Log into AWS using CLI

    ```sh
    export AWS_DEFAULT_REGION="us-west-2" # AWS region change as needed
    export AWS_ACCOUNT_ID="" # AWS Account ID without "-"
    export AWS_ACCESS_KEY_ID=""
    export AWS_SESSION_TOKEN=""
    export AWS_SECRET_ACCESS_KEY=""
    ```

1. Create the ECR repository (if it doesn't exist)

    This is where we'll push the HCP Terraform run task image.

    ```sh
    aws ecr create-repository --region $AWS_DEFAULT_REGION --repository-name hcp-tf-run-task
    ```

1. Retrieve an authentication token and authenticate your Docker client to your registry

    ```sh
    aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
    ```

1. Tag and push the image to the ECR repository

    ```sh
    docker tag hcp-tf-run-task:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/hcp-tf-run-task:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/hcp-tf-run-task:latest
    ```

1. Output the ECR Image URL to use with Terraform > save it in `examples/basic/terraform.auto.tfvars` file

    ```sh
    echo $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/hcp-tf-run-task:latest
    ```
