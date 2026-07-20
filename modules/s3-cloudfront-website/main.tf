
resource "aws_s3_bucket" "hello_world_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "hello_world_bucket_public_access_block" {
  bucket = aws_s3_bucket.hello_world_bucket.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "hello_world_bucket_policy" {
  depends_on = [aws_s3_bucket_public_access_block.hello_world_bucket_public_access_block]
  bucket     = aws_s3_bucket.hello_world_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.hello_world_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.hello_world_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.hello_world_bucket.id
  key          = "index.html"
  source       = "${path.root}/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.root}/index.html")
}

resource "aws_cloudfront_origin_access_control" "hello_world_oac" {
  name                              = "hello-world-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "hello_world_distribution" {
  origin {
    domain_name = aws_s3_bucket.hello_world_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.hello_world_bucket.id}"

    origin_access_control_id = aws_cloudfront_origin_access_control.hello_world_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Hello World CloudFront Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.hello_world_bucket.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
