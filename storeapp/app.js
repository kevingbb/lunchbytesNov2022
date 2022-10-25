const express = require('express');

const app = express();
app.use(express.json());

const port = 3000;

var store = [

]

app.get('/store', (_req, res) => {
    res.json(store)
    console.log(`List of items in the store requested by ${_req.ip}`)
});

app.post('/store', (req, res) => {
    store.push(req.body)
    res.status(200).send("success")
    console.log(`Received new item from ${req.ip}, content: ${JSON.stringify(req.body)}`)
});

app.listen(port, () => console.log(`Node App listening on port ${port}!`));
