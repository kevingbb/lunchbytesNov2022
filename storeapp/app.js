const { config } = require('dotenv');
const { DaprClient, CommunicationProtocolEnum } = require('@dapr/dapr');
const { TableClient, odata } = require("@azure/data-tables");
const express = require('express');
const app = express();
app.use(express.json());
config();

const port = 3000;
const { randomUUID } = require('crypto');

const client = new DaprClient("localhost", process.env.DAPR_HTTP_PORT, CommunicationProtocolEnum.HTTP);
const STATE_STORE_NAME = process.env.STATE_STORE_NAME;
const STORAGE_CONNECTION_STRING = process.env.STORAGE_CONNECTION_STRING;
const TABLE_NAME = process.env.TABLE_NAME;

// Create the TableStorageClient object which will be used to create a container client
const tableClient = TableClient.fromConnectionString(STORAGE_CONNECTION_STRING, TABLE_NAME);

app.get('/count', async (_req, res) => {
    const partitionKey = "storeapp";
    var count = 0;
    // Retrieve minimal amount back and then iterate over results to count.
    const entities = tableClient.listEntities({
        queryOptions: { filter: odata`PartitionKey eq ${partitionKey}`, select: ["RowKey"] }
    });
    for await (const entity of entities) {
        count++
    }
    res.status(200).json(JSON.parse(`{"count": "${count}"}`));
    console.log(`Count of items in the store, ${count}, requested by ${_req.ip}`);
});

app.get('/store', async (_req, res) => {
    const partitionKey = "storeapp";
    // Retrieve data and then iterate over results to count.
    const entities = tableClient.listEntities({
        queryOptions: { filter: odata`PartitionKey eq ${partitionKey}` }
    });
    var allEntities = [];
    for await (const entity of entities) {
        allEntities.push(JSON.parse(`{"id": "${entity.rowKey}", "message": ${entity.Value}}`));
    }
    res.status(200).json(allEntities);
    console.log(`List of items in the store requested by ${_req.ip}`);
});

app.get('/store/:id', async (_req, res) => {
    var result = await client.state.get(STATE_STORE_NAME, _req.params.id);
    res.status(200).json(result);
    console.log(`Get item id ${result.id}, content is ${result.message}, in the store requested by ${_req.ip}`);
});

app.post('/store', async (req, res) => {
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
