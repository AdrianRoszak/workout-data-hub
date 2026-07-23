variable "aws_region" {
  description = "AWS region"
  type = string
  default = "eu-central-1"
}

variable "domain_name" {
  description = "Root domain name (must already exist as a Route 53 hosted zone)"
  type = string
  default = "weirdo.codes"
}

variable "subdomain" {
  description = "Subdomain prefix for the travels service"
  type = string
  default = "travels"
}

variable "athlete_id" {
  description = "Strava athelete ID used to query DynamoDB activities"
  type = string
}