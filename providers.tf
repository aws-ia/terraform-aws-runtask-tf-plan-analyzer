terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~>2.2.0"
    }
  }
}

# for Cloudfront WAF only - must be in us-east-1
provider "aws" {
  region = "us-east-1"
  alias  = "cloudfront_waf"
}
