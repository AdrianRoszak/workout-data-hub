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
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "Weirdo"
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

module "strava_webhook" {
  source = "./modules/strava-webhook"

  strava_client_id     = var.strava_client_id
  strava_client_secret = var.strava_client_secret
  strava_refresh_token = var.strava_refresh_token
  verify_token = var.strava_verify_token
}
