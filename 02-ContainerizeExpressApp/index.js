

const express = require("express")
const bodyParser = require("body-parser")

const app = express()

const port = 3000 

const users = []

app.use(bodyParser.json())

app.get("/", (req, res) => {
    res.send("Hello World!")
})

// Get registered users

app.get('/users', (req, res) => {
    return res.json({users})
})



// Register a new user
app.post('/users', (req, res) => {
    const newUserId = req.body.userId
    if (!newUserId) {
        return res.status(400).send(`Missing userId`)
    }

    if (users.includes(newUserId)) {
        return res.status(400).send(`userId already exists`)
    }

    users.push(newUserId)
    return res.status(201).send(`User registered`)
})



// Reject malformed JSON bodies without dumping a stack trace.
// Four args (next included) is what marks this an error handler.
app.use((err, req, res, next) => {
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        return res.status(400).json({ error: "Invalid JSON body" })
    }
    next(err)
})



// '0.0.0.0' so the container accepts forwarded connections, not just loopback
const server = app.listen(port, '0.0.0.0', () => {
    console.log(`Server listening on port ${port}`);
    
})



// As PID 1 in a container, node does NOT get default signal handling from the
// kernel - without these listeners `docker stop` waits 10s then SIGKILLs.
const shutdown = (signal) => {
    console.log(`${signal} received, shutting down`)
    server.close(() => process.exit(0))
    // Escape hatch if connections refuse to drain
    setTimeout(() => process.exit(1), 5000).unref()
}

process.on("SIGTERM", () => shutdown("SIGTERM"))
process.on("SIGINT", () => shutdown("SIGINT"))