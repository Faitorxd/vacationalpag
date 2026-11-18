output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "alb_http_url" {
  value = "http://${aws_lb.backend.dns_name}"
}

output "alb_https_url" {
  value = "https://${aws_lb.backend.dns_name}"
}

output "webhook_pagos_url" {
  value = "${aws_apigatewayv2_api.webhook.api_endpoint}/webhooks/pagos"
}

output "sqs_pagos_queue_url" {
  value = aws_sqs_queue.pagos.url
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}

output "frontend_website_url" {
  value = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}
