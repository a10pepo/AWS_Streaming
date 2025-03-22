# Create SNS Topic
resource "aws_sns_topic" "my_topic" {
  name = "elements-topic"
}

# Create SQS Queue
resource "aws_sqs_queue" "elements_queue" {
  name = "elements-queue"
}

# Create SNS Topic Subscription to SQS Queue
resource "aws_sns_topic_subscription" "my_subscription" {
  topic_arn = aws_sns_topic.my_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.elements_queue.arn

  # Allow SNS to send messages to SQS
  depends_on = [aws_sqs_queue_policy.elements_queue_policy]
}

# Create SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "elements_queue_policy" {
  queue_url = aws_sqs_queue.elements_queue.id
  policy    = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.elements_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.my_topic.arn
          }
        }
      }
    ]
  })
}


# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach policy to the role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create ECR Repository
resource "aws_ecr_repository" "lambda_repository" {
  name = "lambda-repo"
  force_delete = true
}

# Build and push Docker image to ECR
resource "null_resource" "docker_build_and_push" {
  triggers = {
    always_run = "${timestamp()}"
  }      
  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.lambda_repository.repository_url}
      docker buildx build --platform linux/amd64 -t lambda-repo /Users/pedro.nieto/Documents/CPT/AWS_Streaming/src/terraform/messaging/docker
      docker tag lambda-repo:latest ${aws_ecr_repository.lambda_repository.repository_url}:latest
      docker push ${aws_ecr_repository.lambda_repository.repository_url}:latest
    EOT
  }
  depends_on = [aws_ecr_repository.lambda_repository]
}

# Create Lambda Function
resource "aws_lambda_function" "sqs_lambda" {
  function_name = "sqs-lambda"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_repository.repository_url}:latest"
  timeout       = 30

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.elements_queue.url
      DB_HOST = var.db_host
      DB_USER = var.rds_root_user
      DB_PASS = var.rds_root_pass
      DB_NAME = var.rds_db
    }
  }
  depends_on = [null_resource.docker_build_and_push]
}

# Create SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_event" {
  event_source_arn = aws_sqs_queue.elements_queue.arn
  function_name    = aws_lambda_function.sqs_lambda.arn
  batch_size       = 10
  enabled          = true
}

resource "aws_cloudwatch_log_group" "sqs_lambda_logs" {
  name = "/aws/lambda/sqs-lambda"
}