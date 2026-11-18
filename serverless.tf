resource "aws_sqs_queue" "pagos_dlq" {
  name                      = "${var.prefix}-pagos-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "pagos" {
  name                       = "${var.prefix}-pagos-queue"
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pagos_dlq.arn
    maxReceiveCount     = 3
  })
}

data "archive_file" "lambda_pagos" {
  type        = "zip"
  output_path = "${path.module}/.build/lambda_pagos.zip"

  source {
    filename = "index.mjs"
    content  = <<-EOF
      import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
      const sqs = new SQSClient({ region: process.env.AWS_REGION });

      export const handler = async (event) => {
        if (event.requestContext?.http) {
          const body = typeof event.body === "string" ? JSON.parse(event.body || "{}") : (event.body || {});
          const payload = {
            transactionId: body.transactionId || "TX-" + Date.now(),
            studentId: body.studentId || "EST-UPC-001",
            courseCode: body.courseCode || "ING-SW-VAC",
            amount: body.amount || 190000,
            method: body.method || "PSE",
            receivedAt: new Date().toISOString()
          };
          await sqs.send(new SendMessageCommand({
            QueueUrl: process.env.SQS_QUEUE_URL,
            MessageBody: JSON.stringify(payload)
          }));
          return {
            statusCode: 202,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ ok: true, message: "Pago encolado en SQS", transactionId: payload.transactionId })
          };
        }

        const batchItemFailures = [];
        for (const record of event.Records || []) {
          try {
            const payment = JSON.parse(record.body);
            console.log("Pago confirmado en VacacionalPag:", JSON.stringify(payment));
          } catch (err) {
            console.error("Fallo procesando mensaje:", record.messageId, err);
            batchItemFailures.push({ itemIdentifier: record.messageId });
          }
        }
        return { batchItemFailures };
      };
    EOF
  }
}

resource "aws_lambda_function" "procesar_pagos" {
  function_name    = "${var.prefix}-procesar-pagos"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda_pagos.output_path
  source_code_hash = data.archive_file.lambda_pagos.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = [aws_subnet.priv_app_a.id, aws_subnet.priv_app_b.id]
    security_group_ids = [aws_security_group.backend.id]
  }

  environment {
    variables = {
      DB_HOST               = aws_db_instance.postgres.address
      SSM_DB_PASSWORD_PATH  = aws_ssm_parameter.db_password.name
      SQS_QUEUE_URL         = aws_sqs_queue.pagos.url
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_pagos" {
  event_source_arn        = aws_sqs_queue.pagos.arn
  function_name           = aws_lambda_function.procesar_pagos.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}

data "archive_file" "lambda_cierre" {
  type        = "zip"
  output_path = "${path.module}/.build/lambda_cierre.zip"

  source {
    filename = "index.mjs"
    content  = <<-EOF
      export const handler = async (event) => {
        console.log("Evaluando punto de equilibrio diario VacacionalPag:", JSON.stringify(event));
        return { status: "OK", evaluatedAt: new Date().toISOString() };
      };
    EOF
  }
}

resource "aws_lambda_function" "cierre_cursos" {
  function_name    = "${var.prefix}-cierre-cursos"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda_cierre.output_path
  source_code_hash = data.archive_file.lambda_cierre.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = [aws_subnet.priv_app_a.id, aws_subnet.priv_app_b.id]
    security_group_ids = [aws_security_group.backend.id]
  }

  environment {
    variables = {
      DB_HOST              = aws_db_instance.postgres.address
      SSM_DB_PASSWORD_PATH = aws_ssm_parameter.db_password.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "cierre_diario" {
  name                = "${var.prefix}-cierre-diario-rule"
  description         = "Evaluacion diaria de cupos minimos VacacionalPag"
  schedule_expression = "cron(0 5 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cierre_target" {
  rule      = aws_cloudwatch_event_rule.cierre_diario.name
  target_id = "1"
  arn       = aws_lambda_function.cierre_cursos.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cierre_cursos.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cierre_diario.arn
}

resource "aws_apigatewayv2_api" "webhook" {
  name          = "${var.prefix}-webhook-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "webhook_lambda" {
  api_id                 = aws_apigatewayv2_api.webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.procesar_pagos.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook_route" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /webhooks/pagos"
  target    = "integrations/${aws_apigatewayv2_integration.webhook_lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.procesar_pagos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*"
}
