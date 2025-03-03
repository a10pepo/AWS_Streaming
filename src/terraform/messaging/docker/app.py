import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Initialize SQS client
    sqs_client = boto3.client('sqs')
    
    # Get the queue URL
    queue_url = sqs_client.get_queue_url(QueueName='elements-queue')['QueueUrl']
    
    # Process each message in the event
    for record in event['Records']:
        # Get the message body
        message_body = record['body']
        
        # Log the message body
        logger.info(f"Received message: {message_body}")
        
        # Process the message (add your custom logic here)
        process_message(message_body)
        
        # Delete the message from the queue
        receipt_handle = record['receiptHandle']
        sqs_client.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle
        )
        logger.info(f"Deleted message: {receipt_handle}")

def process_message(message_body):
    # Add your custom message processing logic here
    logger.info(f"Processing message: {message_body}")