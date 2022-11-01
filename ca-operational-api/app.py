import json
import os
import requests
import logging
import flask
from flask import request, jsonify
from flask_cors import CORS

logging.basicConfig(level=logging.INFO)

dapr_port = os.getenv("DAPR_HTTP_PORT") or 3603
orders_url = "http://localhost:{}/v1.0/invoke/storeapp/method/count".format(dapr_port)
queue_url = "http://localhost:{}/v1.0/invoke/queuereader/method/count".format(dapr_port)

app = flask.Flask(__name__)
CORS(app)

@app.route('/orders', methods=['GET'])
def getorders():
    response = requests.get(orders_url)
    return response.text

@app.route('/queue', methods=['GET'])
def getqueuemessages():
    response = requests.get(queue_url)
    return response.text

app.run(host='0.0.0.0')
