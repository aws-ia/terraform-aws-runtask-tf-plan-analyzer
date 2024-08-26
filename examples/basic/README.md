<!-- BEGIN_TF_DOCS -->
# Usage Example

This is a basic example setup on using the module.

* Make sure the Docker image has been built and pushed from the `src` folder, [follow this Readme](../../src/README.md)

* Create infrastrucutre

  ```bash
  terraform init
  terraform plan
  terraform apply
  ```

* (Optional, if using HCP Terraform) Add the cloud block in `providers.tf`

  ```hcl
  terraform {

    cloud {
      # TODO: Change this to your HCP Terraform org name.
      organization = "<enter your org name here>"
      workspaces {
        ...
      }
    }
    ...
  }
  ```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.56.1 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | ~>0.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.56.1 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | ~>0.38.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_hcp_tf_run_task"></a> [hcp\_tf\_run\_task](#module\_hcp\_tf\_run\_task) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [tfe_organization_run_task.bedrock_plan_analyzer](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/organization_run_task) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/5.56.1/docs/data-sources/region) | data source |
| [tfe_organization.hcp_tf_org](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hcp_tf_org"></a> [hcp\_tf\_org](#input\_hcp\_tf\_org) | HCP Terraform Organization name | `string` | n/a | yes |
| <a name="input_hcp_tf_token"></a> [hcp\_tf\_token](#input\_hcp\_tf\_token) | HCP Terraform API token | `string` | n/a | yes |
| <a name="input_tf_run_task_logic_image"></a> [tf\_run\_task\_logic\_image](#input\_tf\_run\_task\_logic\_image) | Docker image for the HCP Terraform run task logic | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy the resources | `string` | `"us-east-1"` | no |
| <a name="input_tf_run_task_image_tag"></a> [tf\_run\_task\_image\_tag](#input\_tf\_run\_task\_image\_tag) | value for the docker image tag to be used by the run task logic | `string` | `"latest"` | no |
| <a name="input_tf_run_task_logic_iam_roles"></a> [tf\_run\_task\_logic\_iam\_roles](#input\_tf\_run\_task\_logic\_iam\_roles) | values for the IAM roles to be used by the run task logic | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_runtask_url"></a> [runtask\_url](#output\_runtask\_url) | n/a |
<!-- END_TF_DOCS -->