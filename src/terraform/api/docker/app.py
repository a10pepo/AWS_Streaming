from flask import Flask, request, jsonify, render_template, redirect, url_for
from flasgger import Swagger
import logging
import boto3
import pymysql
import random
import os

app = Flask(__name__)
swagger = Swagger(app)

# Configure logging
logging.basicConfig(level=logging.DEBUG)

# RDS MySQL connection details
RDS_HOST = os.getenv('RDS_HOST', 'default-host')
RDS_USER = os.getenv('RDS_USER', 'default-user')
RDS_DB = os.getenv('RDS_DB', 'default-db')
REGION = "eu-central-1"

def get_db_connection():
    print(f"RDS_HOST: {RDS_HOST}")
    print(f"AWS_EXECUTION_ENV: {os.getenv('AWS_EXECUTION_ENV')}")
    print(f"AWS_REGION: {os.getenv('AWS_REGION')}")
    print(f"RDS_USER: {RDS_USER}")
    print(f"RDS_DB: {RDS_DB}")
    print(f"REGION: {REGION}")


    # Check if running in AWS environment
    if not os.getenv('AWS_EXECUTION_ENV'):
        # Assume role
        sts_client = boto3.client('sts')
        assumed_role_object = sts_client.assume_role(
            RoleArn="arn:aws:iam::575240114042:role/app-runner-role",
            RoleSessionName="AssumeRoleSession1"
        )
        credentials = assumed_role_object['Credentials']
        print(f"Assumed role {credentials['AccessKeyId']}")
    else:
        # Use local credentials
        session = boto3.Session()
        credentials = session.get_credentials().get_frozen_credentials()
        credentials = {
            'AccessKeyId': credentials.access_key,
            'SecretAccessKey': credentials.secret_key,
            'SessionToken': credentials.token
        }        
    # # Print current sts get_caller_identity
    # sts_client = boto3.client('sts', region_name=REGION, aws_access_key_id=credentials['AccessKeyId'], aws_secret_access_key=credentials['SecretAccessKey'], aws_session_token=credentials['SessionToken'])
    # print(sts_client.get_caller_identity())

    # # Generate an IAM authentication token
    # rds_client = boto3.client('rds', region_name=REGION, aws_access_key_id=credentials['AccessKeyId'], aws_secret_access_key=credentials['SecretAccessKey'], aws_session_token=credentials['SessionToken'])
    # token = rds_client.generate_db_auth_token(
    #     DBHostname=RDS_HOST.split(':')[0],
    #     Port=3306,
    #     DBUsername=RDS_USER,
    #     Region=REGION
    # )

    # Connect to the RDS instance using the IAM authentication token
    connection = pymysql.connect(
        host=RDS_HOST.split(':')[0],
        user=RDS_USER,
        password=os.getenv('RDS_PASS'),
        db=RDS_DB,
        port=3306,
        cursorclass=pymysql.cursors.DictCursor
    )
    return connection


# In-memory database
items = [
    {"id": 1, "name": "Apple", "price": 0.5, "quantity": 100},
    {"id": 2, "name": "Banana", "price": 0.3, "quantity": 150},
    {"id": 3, "name": "Orange", "price": 0.7, "quantity": 80}
]

def init_db():
    # Initialize an RDS Database
    connection = get_db_connection()
    if connection is None:
        logging.error("Failed to connect to the database")
        return
    else:
        logging.info("Connected to the database")
    try:
        with connection.cursor() as cursor:
            # Create a table for storing items
            cursor.execute("CREATE TABLE IF NOT EXISTS items (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255), price DECIMAL(10, 2), quantity INT, description TEXT)")
            connection.commit()

            # Insert some sample items
            cursor.execute("INSERT INTO items (name, price, quantity, description) VALUES ('Apple', 0.5, 100, 'Fresh red apples')")
            cursor.execute("INSERT INTO items (name, price, quantity, description) VALUES ('Banana', 0.3, 150, 'Ripe yellow bananas')")
            cursor.execute("INSERT INTO items (name, price, quantity, description) VALUES ('Orange', 0.7, 80, 'Juicy oranges')")
            connection.commit()
    finally:
        connection.close()

    

@app.route('/')
def index():
    return render_template('index.html', items=items)

@app.route('/items', methods=['GET'])
def get_items():
    """
    Get all items
    ---
    responses:
      200:
        description: A list of items
        schema:
          type: array
          items:
            type: object
            properties:
              id:
                type: integer
              name:
                type: string
              price:
                type: number
              quantity:
                type: integer
    """
    try:
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "SELECT id, name, price, quantity, description FROM items"
                cursor.execute(sql)
                result = cursor.fetchall()
        finally:
            connection.close()
        return jsonify(result)
    except Exception as e:
        logging.error(e)
        return jsonify(items)

@app.route('/new', methods=['GET'])
def new():
    return render_template('new.html')


@app.route('/addproduct', methods=['POST'])
def add_item():
    logging.info("Adding new product to the database...")
    new_item = {
        "id": len(items) + 1,
        "name": request.form['name'],
        "price": float(request.form['price']),
        "quantity": int(request.form['quantity']),
        "description": request.form['description']
    }
    items.append(new_item)

    # Initialize a session using Amazon SNS
    sns_client = boto3.client('sns', region_name='eu-central-1')

    # Send a message to the specified SNS topic
    response = sns_client.publish(
        TopicArn='arn:aws:sns:eu-central-1:575240114042:elements-topic',
        Message=f"New product added: {new_item['name']}, Price: {new_item['price']}, Quantity: {new_item['quantity']}, Description: {new_item['description']}",
        Subject='New Product Added'
    )
    logging.info(f"Response: {response}")

    return "Product added successfully"

@app.route('/buyproduct', methods=['POST'])
def buy_product():
    logging.info("Buying product...")
    logging.info(f"Product: {request.form['product']}, Quantity: {request.form['quantity']}")
    product = request.form['product']
    quantity = int(request.form['quantity'])

    # Initialize a session using Amazon SNS
    sns_client = boto3.client('sns', region_name='eu-central-1')

    # Send a message to the specified SNS topic
    response = sns_client.publish(
        TopicArn='arn:aws:sns:eu-central-1:575240114042:elements-topic',
        Message=f"Buy: Id:{product}, Quantity: {quantity}",
        Subject='New Product Bought'
    )
    logging.info(f"Response: {response}")

    return "Product bought successfully"

@app.context_processor
def inject_random_number():
    return {'random_number': random.randint(100000000000, 999999999999)}


if __name__ == '__main__':
    logging.info("Initializing database...")
    init_db()
    logging.info("Starting Flask app...")
    try:
        app.run(host='0.0.0.0', port=8000, debug=True)
    except Exception as e:
        logging.error(e)