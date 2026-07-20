terraform {
  backend "s3" {
    bucket       = "terraform-state-weirdo-bucket-REDACTED_ACCOUNT_ID"
    key          = "terraform.tfstate"
    profile      = "Weirdo"
    region       = "eu-central-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "Weirdo"
}

module "website" {
  source      = "./modules/s3-cloudfront-website"
  bucket_name = local.bucket_name
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = local.terraform_state_bucket_name
}

resource "aws_s3_bucket_versioning" "terraform_state_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
