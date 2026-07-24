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

resource "aws_s3_bucket_public_access_block" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_route53_zone" "weirdo_codes" {
  name    = "weirdo.codes"
  comment = "Primary hosted zone for weirdo.codes"
}

# MX — Zoho mail
resource "aws_route53_record" "weirdo_mx" {
  zone_id = aws_route53_zone.weirdo_codes.zone_id
  name    = "weirdo.codes"
  type    = "MX"
  ttl     = 3600
  records = [
    "10 mx.zoho.eu.",
    "20 mx2.zoho.eu.",
    "50 mx3.zoho.eu.",
  ]
}

# SPF — Zoho
resource "aws_route53_record" "weirdo_spf" {
  zone_id = aws_route53_zone.weirdo_codes.zone_id
  name    = "weirdo.codes"
  type    = "TXT"
  ttl     = 3600
  records = ["v=spf1 include:zoho.eu ~all"]
}

module "strava_webhook" {
  source = "./modules/strava-webhook"

  strava_client_id     = var.strava_client_id
  strava_client_secret = var.strava_client_secret
  strava_refresh_token = var.strava_refresh_token
  verify_token = var.strava_verify_token
}

module "travels_map" {
  source = "./modules/travels-map"

  athlete_id      = var.strava_athlete_id
  route53_zone_id = aws_route53_zone.weirdo_codes.zone_id
}
