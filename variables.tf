variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "eu-central-1"
}

variable "strava_client_id" {
  description = "Strava OAuth Client ID"
  type        = string
  sensitive   = true
}

variable "strava_client_secret" {
  description = "Strava OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "strava_refresh_token" {
  description = "Strava OAuth Refresh Token (valid 6 months, rotates on each use)"
  type        = string
  sensitive   = true
}

variable "strava_verify_token" {
  description = "Secret token used by Strava to authenticate webhook subscription callback. Must match the verify_token configured in the Strava API subscription."
  type        = string
  sensitive   = true
}