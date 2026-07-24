provider "aws" {
  region  = "us-east-1"
  alias   = "virginia"
  profile = "Weirdo"
}

resource "aws_lambda_function" "get_hiking_routes" {
  function_name = "getHikingRoutes"
  runtime = "python3.14"
  handler = "lambda_function.lambda_handler"
  role = aws_iam_role.lambda_exec.arn
  filename = "${path.module}/src/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/src/lambda_function.zip")
  timeout = 10
  memory_size = 128
  architectures = ["arm64"]

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = data.aws_dynamodb_table.strava_activities.name
      ATHLETE_ID          = var.athlete_id
    }
  }
}

resource "aws_lambda_permission" "get_hiking_routes" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = "getHikingRoutes"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.get_hiking_routes.execution_arn}/*/*/getHikingRoutes"
}

resource "aws_apigatewayv2_api" "get_hiking_routes" {
  name        = "travelsMapHandler-API"
  description = "HTTP API that receives requests from the travels map frontend and proxies them to the getHikingRoutes Lambda"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "get_hiking_routes" {
  api_id = aws_apigatewayv2_api.get_hiking_routes.id
  route_key = "GET /api/activities"
  target = "integrations/${aws_apigatewayv2_integration.get_hiking_routes.id}"
}

resource "aws_apigatewayv2_route" "get_hiking_route_by_id" {
  api_id = aws_apigatewayv2_api.get_hiking_routes.id
  route_key = "GET /api/activities/{id}"
  target = "integrations/${aws_apigatewayv2_integration.get_hiking_routes.id}"
}

resource "aws_apigatewayv2_integration" "get_hiking_routes" {
  api_id = aws_apigatewayv2_api.get_hiking_routes.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.get_hiking_routes.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_stage" "get_hiking_routes" {
  api_id      = aws_apigatewayv2_api.get_hiking_routes.id
  name        = "default"
  auto_deploy = true
  description = "Production stage for the Get Hiking Routes endpoint. Auto-deploys on route/integration changes."

  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit = 10
  }
}

resource "aws_s3_bucket" "travels_map_front" {
  bucket = "travels-map-weirdo-bucket-REDACTED_ACCOUNT_ID"
}

resource "aws_s3_bucket_public_access_block" "travels_map_front" {
  bucket = aws_s3_bucket.travels_map_front.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "travels_map_front_versioning" {
  bucket = aws_s3_bucket.travels_map_front.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "travels_map_front" {
  bucket = aws_s3_bucket.travels_map_front.id
  policy = data.aws_iam_policy_document.s3_cloudfront_read.json
}

data "aws_iam_policy_document" "s3_cloudfront_read" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.travels_map.iam_arn]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.travels_map_front.arn}/*"]
  }
}

resource "aws_cloudfront_distribution" "travels_map" {
  comment = "CloudFront distribution for travels.weirdo.codes – serves Leaflet.js frontend from S3 and proxies /api/* to API Gateway"
  enabled = true
  is_ipv6_enabled = true
  price_class = "PriceClass_100"
  aliases = ["${var.subdomain}.${var.domain_name}"]

#Origin: S3
  origin {
    domain_name = aws_s3_bucket.travels_map_front.bucket_regional_domain_name
    origin_id = "S3-travels-map"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.travels_map.cloudfront_access_identity_path
    }
  }

  #Origin: API Gateway
  origin {
    domain_name = replace(aws_apigatewayv2_api.get_hiking_routes.api_endpoint, "/^https?://([^/]*).*/", "$1")
    origin_id = "APIGW-travels"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  # /api/* → API Gateway
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "APIGW-travels"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  # default → S3
  default_cache_behavior {
    target_origin_id       = "S3-travels-map"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.travels_map.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "travels_map" {
  comment = "OAI for travels-map CloudFront -> S3 access"
}

resource "aws_iam_role" "lambda_exec" {
  name        = "getHikingRoutes-role"
  path        = "/service-role/"
  description = "Execution role for the getHikingRoutes Lambda – allows reading from DynamoDB and writing CloudWatch logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_get_hiking_routes_access" {
  name        = "GetHikingRoutesAccess"
  role        = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
        ]
        Resource = data.aws_dynamodb_table.strava_activities.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role = aws_iam_role.lambda_exec.name
policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_dynamodb_table" "strava_activities" {
  name = "StravaActivities"
}

resource "aws_acm_certificate" "travels_map" {
  provider          = aws.virginia
  domain_name       = "${var.subdomain}.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation record for ACM certificate — created in the Route 53 hosted zone
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.travels_map.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.travels_subdomain.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "travels_map" {
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.travels_map.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

resource "aws_s3_bucket_website_configuration" "travels_map_front" {
  bucket = aws_s3_bucket.travels_map_front.id

  index_document {
    suffix = "index.html"
  }
}

# Hosted zone ONLY for the subdomain travels.weirdo.codes
# Parent domain weirdo.codes stays managed by Vercel/Gandi
resource "aws_route53_zone" "travels_subdomain" {
  name    = "${var.subdomain}.${var.domain_name}"
  comment = "Delegated subdomain for the travels map service — NS records must be added in Vercel for the parent domain"
}

resource "aws_route53_record" "travels" {
  zone_id = aws_route53_zone.travels_subdomain.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.travels_map.domain_name
    zone_id                = aws_cloudfront_distribution.travels_map.hosted_zone_id
    evaluate_target_health = false
  }
}
