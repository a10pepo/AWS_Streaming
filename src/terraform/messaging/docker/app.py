import json
import boto3
import logging
import pymysql
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RDS_HOST = os.getenv('RDS_HOST', 'default-host')
RDS_USER = os.getenv('RDS_USER', 'default-user')
RDS_DB = os.getenv('RDS_DB', 'default-db')

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    logger.info(f"RDS_HOST: {RDS_HOST}")
    logger.info(f"RDS_USER: {RDS_USER}")
    logger.info(f"RDS_DB: {RDS_DB}")

    connection = pymysql.connect(
        host=RDS_HOST.split(':')[0],
        user=RDS_USER,
        password=os.getenv('RDS_PASS'),
        db=RDS_DB,
        port=3306,
        cursorclass=pymysql.cursors.DictCursor
    )
    
    try:
        with connection.cursor() as cursor:
            # Insert some sample items
            cursor.execute("INSERT INTO items (name, price, quantity, description) VALUES ('PEDRO', 0.5, 100, 'Fresh red apples')")
            connection.commit()
    finally:
        connection.close()

def process_message(message_body):
    # Add your custom message processing logic here
    logger.info(f"Processing message: {message_body}")