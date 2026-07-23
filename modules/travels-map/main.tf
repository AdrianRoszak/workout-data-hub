resource "aws_lambda_function" "get_hiking_routes" {}

resource "aws_apigatewayv2_api" "get_hiking_routes" {
  name = "travelsMapHandler-API"
  description = ""
  protocol_type = "HTTP"
}

resource "aws_s3_bucket" {}

resource "aws_cloudfront_distribution" {}

resource "aws_iam_role" "lamda_exec" {}

data "aws_dynamodb_table" {
  name = "StravaActivities"
}