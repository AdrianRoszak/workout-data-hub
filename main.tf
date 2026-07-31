terraform {
  backend "s3" {
    bucket       = "terraform-state-weirdo-bucket-${var.aws_account_id}"
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

# A — Vercel (strona główna)
resource "aws_route53_record" "weirdo_a" {
  zone_id = aws_route53_zone.weirdo_codes.zone_id
  name    = "weirdo.codes"
  type    = "A"
  ttl     = 300
  records = ["76.76.21.21"]
}

resource "aws_route53_record" "www_weirdo_a" {
  zone_id = aws_route53_zone.weirdo_codes.zone_id
  name    = "www.weirdo.codes"
  type    = "A"
  ttl     = 300
  records = ["76.76.21.21"]
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

# DKIM — Zoho (zmail selector)
resource "aws_route53_record" "weirdo_dkim" {
  zone_id = aws_route53_zone.weirdo_codes.zone_id
  name    = "zmail._domainkey.weirdo.codes"
  type    = "TXT"
  ttl     = 3600
  records = [
    "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCA/3WxPUURq6owUyy2OwJSHbmkqd9oOyywRUosDscI6Ejuj43OznCM4dC99MOJwF5Nk6VeZw1HkDV9Or6HslMmiOj1ukJif5/0LkWrapmevD9ebqTbecDpL6so1GvCG59s0RFnchjq0Uf3/pXBRjL0FZfQTFgHTkLE6LBVzLeprwIDAQAB"
  ]
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
