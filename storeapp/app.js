const { config } = require('dotenv');
const { DaprClient, CommunicationProtocolEnum } = require('@dapr/dapr');
const { BlobServiceClient } = require('@azure/storage-blob');
const express = require('express');
const app = express();
app.use(express.json());
config();

const port = 3000;
const { randomUUID } = require('crypto');

const client = new DaprClient("localhost", process.env.DAPR_HTTP_PORT, CommunicationProtocolEnum.HTTP);
const STATE_STORE_NAME = process.env.STATE_STORE_NAME;
const BLOB_CONNECTION_STRING = process.env.BLOB_CONNECTION_STRING;
const CONTAINER_NAME = process.env.CONTAINER_NAME;

// Create the BlobServiceClient object which will be used to create a container client
const blobServiceClient = BlobServiceClient.fromConnectionString(BLOB_CONNECTION_STRING);

function streamToBuffer(stream) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        stream.on("data", (data) => {
        chunks.push(Buffer.isBuffer(data) ? data : Buffer.from(data));
        });
        stream.on("end", () => {
        resolve(Buffer.concat(chunks));
        });
        stream.on("error", reject);
    });
}

app.get('/store/count', async (_req, res) => {
    // Get a reference to a container
    const containerClient = blobServiceClient.getContainerClient(CONTAINER_NAME);
    // List the blob(s) in the container.
    var count = 0;
    for await (const blob of containerClient.listBlobsFlat()) {
        count++
    }
    res.status(200).json(JSON.parse(`{"count": "${count}"}`));
    console.log(`Count of items in the store, ${count}, requested by ${_req.ip}`);
});

app.get('/store', async (_req, res) => {
    // Get a reference to a container
    const containerClient = blobServiceClient.getContainerClient(CONTAINER_NAME);
    // List the blob(s) in the container.
    var store = [];
    for await (const blob of containerClient.listBlobsFlat()) {
        blockBlobClient = containerClient.getBlockBlobClient(blob.name);
        const downloadBlockBlobResponse = await blockBlobClient.download();
        const blobText = await streamToBuffer(downloadBlockBlobResponse.readableStreamBody);
        store.push(JSON.parse(`{"id": "${blob.name}", "message": ${blobText}}`));
    }
    res.status(200).json(store);
    console.log(`List of items in the store requested by ${_req.ip}`);
});

app.get('/store/:id', async (_req, res) => {
    var result = await client.state.get(STATE_STORE_NAME, _req.params.id);
    res.status(200).json(result);
    console.log(`Get item id ${result.id}, content is ${result.message}, in the store requested by ${_req.ip}`);
});

app.post('/store', async (req, res) => {
    console.log(STATE_STORE_NAME);
    await client.state.save(STATE_STORE_NAME, [
        {
            key: randomUUID(),
            value: req.body.message
        }
    ]);
    res.status(200).send("success");
    console.log(`Received new item from ${req.ip}, content: ${JSON.stringify(req.body)}`);
});

app.listen(port, () => console.log(`Node App listening on port ${port}!`));
