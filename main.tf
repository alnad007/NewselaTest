# Create a VPC
resource "aws_vpc" "newselatest" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_s3_bucket" "static_site_bucket" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_acl" "static_site_bucket" {
  bucket = aws_s3_bucket.static_site_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "static_site_bucket_policy" {
  bucket = aws_s3_bucket.static_site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::${local.bucket_name}/*"]
      }
    ]
  })
}

resource "aws_cloudfront_origin_access_identity" "cf_oai" {
  comment = "${var.app_name}-${var.environment}-static-site OAI"
}

resource "aws_cloudfront_distribution" "static_site_cdn" {
  origin {
    domain_name = aws_s3_bucket.static_site_bucket.bucket_regional_domain_name
    origin_id   = local.bucket_name

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.cf_oai.id}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = local.bucket_name

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    min_ttl = var.default_ttl
    max_ttl = var.default_ttl
    default_ttl = var.default_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "arn:aws:acm:us-east-1:727318652615:certificate/bab36da0-14e5-460d-a995-3e92afe75231"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  aliases = local.cf_aliases

}

resource "aws_route53_zone" "zone" {
  name = "newselatest.com"
}

resource "aws_route53_record" "cname" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "${var.app_name}-${var.environment}.newselatest.com"
  type    = "CNAME"
  ttl     = var.default_ttl
  records = [aws_cloudfront_distribution.static_site_cdn.domain_name]

  depends_on = [aws_cloudfront_distribution.static_site_cdn]
}

output "bucket_name" {
  value = aws_s3_bucket.static_site_bucket.id
}

resource "aws_iam_role" "beanstalk_service" {
  name = "beanstalk_service"

  assume_role_policy = jsonencode({
    
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
  

resource "aws_elastic_beanstalk_application" "newselatest" {
  name        = var.app_name

  appversion_lifecycle {
    service_role          = aws_iam_role.beanstalk_service.arn
    max_count             = 128
    delete_source_from_s3 = true
  }
}
