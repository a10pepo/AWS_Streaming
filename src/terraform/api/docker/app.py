from flask import Flask, request, jsonify, render_template, redirect, url_for
from flasgger import Swagger
import logging
import boto3

app = Flask(__name__)
swagger = Swagger(app)

# Configure logging
logging.basicConfig(level=logging.DEBUG)

# In-memory database
items = [
    {"id": 1, "name": "Apple", "price": 0.5, "quantity": 100},
    {"id": 2, "name": "Banana", "price": 0.3, "quantity": 150},
    {"id": 3, "name": "Orange", "price": 0.7, "quantity": 80}
]


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
    return jsonify(items)

@app.route('/new', methods=['GET'])
def new():
    return render_template('new.html')

@app.route('/addproduct', methods=['POST'])
def add_item():
    new_item = {
        "id": len(items) + 1,
        "name": request.form['name'],
        "price": float(request.form['price']),
        "quantity": int(request.form['quantity']),
        "description": request.form['description']
    }
    items.append(new_item)

    # Assume the IAM role
    sts_client = boto3.client('sts')
    assumed_role = sts_client.assume_role(
        RoleArn='arn:aws:iam::575240114042:role/app-runner-role',  # Replace with your role ARN
        RoleSessionName='AssumeRoleSession'
    )

    # Initialize a session using Amazon SNS
    sns_client = boto3.client('sns', region_name='eu-central-1')

    # Send a message to the specified SNS topic
    response = sns_client.publish(
        TopicArn='arn:aws:sns:eu-central-1:575240114042:elements-topic',
        Message=f"New product added: {new_item['name']}, Price: {new_item['price']}, Quantity: {new_item['quantity']}, Description: {new_item['description']}",
        Subject='New Product Added'
    )

    return redirect(url_for('index')) 

if __name__ == '__main__':
    logging.info("Starting Flask app...")
    try:
        app.run(host='0.0.0.0', port=8000, debug=True)
    except Exception as e:
        logging.error(e)