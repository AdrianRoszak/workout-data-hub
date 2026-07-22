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