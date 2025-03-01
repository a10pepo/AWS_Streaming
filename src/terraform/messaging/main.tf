# Create SNS Topic
resource "aws_sns_topic" "my_topic" {
  name = "elements-topic"
}

# Create SQS Queue
resource "aws_sqs_queue" "my_queue" {
  name = "elements-queue"
}

# Create SNS Topic Subscription to SQS Queue
resource "aws_sns_topic_subscription" "my_subscription" {
  topic_arn = aws_sns_topic.my_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.my_queue.arn

  # Allow SNS to send messages to SQS
  depends_on = [aws_sqs_queue_policy.my_queue_policy]
}

# Create SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "my_queue_policy" {
  queue_url = aws_sqs_queue.my_queue.id
  policy    = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.my_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.my_topic.arn
          }
        }
      }
    ]
  })
}