# Lambda function to process analytics events
resource "aws_lambda_function" "analytics_processor" {
  filename      = data.archive_file.analytics_lambda.output_path
  function_name = "${var.environment}-ghost-analytics-processor"
  role          = aws_iam_role.analytics_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  source_code_hash = data.archive_file.analytics_lambda.output_base64sha256

  environment {
    variables = {
      PAGEVIEWS_LOG_GROUP      = aws_cloudwatch_log_group.pageviews.name
      USER_ANALYTICS_LOG_GROUP = aws_cloudwatch_log_group.user_analytics.name
      ENGAGEMENT_LOG_GROUP     = aws_cloudwatch_log_group.engagement.name
      ENVIRONMENT              = var.environment
    }
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-analytics-processor"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Create Lambda function code
resource "local_file" "analytics_lambda_code" {
  filename = "${path.module}/lambda/index.js"
  content  = <<-EOT
const { CloudWatchLogsClient, PutLogEventsCommand, CreateLogStreamCommand } = require("@aws-sdk/client-cloudwatch-logs");

const cloudwatch = new CloudWatchLogsClient({});

const PAGEVIEWS_LOG_GROUP = process.env.PAGEVIEWS_LOG_GROUP;
const USER_ANALYTICS_LOG_GROUP = process.env.USER_ANALYTICS_LOG_GROUP;
const ENGAGEMENT_LOG_GROUP = process.env.ENGAGEMENT_LOG_GROUP;

exports.handler = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  try {
    // Parse the incoming event
    const body = JSON.parse(event.body || '{}');
    const eventType = body.event_type;
    const timestamp = Date.now();

    // Enrich with server-side data
    const enrichedEvent = {
      ...body,
      server_timestamp: new Date().toISOString(),
      ip_address: event.requestContext?.identity?.sourceIp || 'unknown',
      user_agent: event.headers?.['User-Agent'] || 'unknown',
      country: event.headers?.['CloudFront-Viewer-Country'] || 'unknown',
      city: event.headers?.['CloudFront-Viewer-City'] || 'unknown'
    };

    // Determine which log group to use
    let logGroupName;
    switch (eventType) {
      case 'pageview':
        logGroupName = PAGEVIEWS_LOG_GROUP;
        break;
      case 'engagement':
        logGroupName = ENGAGEMENT_LOG_GROUP;
        break;
      case 'click':
      default:
        logGroupName = USER_ANALYTICS_LOG_GROUP;
    }

    // Create log stream name (daily rotation)
    const date = new Date().toISOString().split('T')[0];
    const logStreamName = `$${eventType}-$${date}`;

    // Try to create log stream (ignore if it already exists)
    try {
      await cloudwatch.send(new CreateLogStreamCommand({
        logGroupName: logGroupName,
        logStreamName: logStreamName
      }));
    } catch (error) {
      // Ignore error if stream already exists
      if (error.name !== 'ResourceAlreadyExistsException') {
        console.log('Error creating log stream:', error);
      }
    }

    // Send log event
    await cloudwatch.send(new PutLogEventsCommand({
      logGroupName: logGroupName,
      logStreamName: logStreamName,
      logEvents: [
        {
          message: JSON.stringify(enrichedEvent),
          timestamp: timestamp
        }
      ]
    }));

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ success: true })
    };
  } catch (error) {
    console.error('Error processing analytics:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};
EOT
}

# Package Lambda function
data "archive_file" "analytics_lambda" {
  type        = "zip"
  source_file = local_file.analytics_lambda_code.filename
  output_path = "${path.module}/lambda/analytics.zip"

  depends_on = [local_file.analytics_lambda_code]
}

# IAM Role for Lambda
resource "aws_iam_role" "analytics_lambda" {
  name = "${var.environment}-ghost-analytics-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "analytics_lambda" {
  name = "analytics-logging"
  role = aws_iam_role.analytics_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.pageviews.arn,
          "${aws_cloudwatch_log_group.pageviews.arn}:*",
          aws_cloudwatch_log_group.user_analytics.arn,
          "${aws_cloudwatch_log_group.user_analytics.arn}:*",
          aws_cloudwatch_log_group.engagement.arn,
          "${aws_cloudwatch_log_group.engagement.arn}:*",
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.environment}-ghost-analytics-processor:*"
        ]
      }
    ]
  })
}

# API Gateway for Lambda
resource "aws_apigatewayv2_api" "analytics" {
  name          = "${var.environment}-ghost-analytics-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # Restrict this to your domain in production
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }

  tags = var.tags
}

resource "aws_apigatewayv2_stage" "analytics" {
  api_id      = aws_apigatewayv2_api.analytics.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}/ghost-analytics"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-analytics-api-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_apigatewayv2_integration" "analytics" {
  api_id           = aws_apigatewayv2_api.analytics.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration for analytics"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.analytics_processor.invoke_arn
}

resource "aws_apigatewayv2_route" "analytics" {
  api_id    = aws_apigatewayv2_api.analytics.id
  route_key = "POST /track"
  target    = "integrations/${aws_apigatewayv2_integration.analytics.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.analytics.execution_arn}/*/*"
}
