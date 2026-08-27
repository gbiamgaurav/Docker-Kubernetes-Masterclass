
const express = require("express")
const mongoose = require("mongoose")
const bodyParser = require("body-parser")

const app = express()

app.use(bodyParser.json())

app.get('/health', (req, res) => {
    res.status(200).send('up')
})


console.log('Connecting to DB');


mongoose.connect('mongodb://mongodb/key-value-db', {
    auth: {
        username: 'key-value-user',
        password: 'key-value-password'
    },
    connectTimeoutMS: 100

}).then(() => {
    app.listen(3000, () => {
        console.log('Listening on port 3000');
        
    })
    console.log('Connected to DB')})
.catch(err => {
    console.error('Something went wrong!')
    console.error(err)});

