const express = require('express');
const bodyParser = require('body-parser');
const mysql = require('mysql2/promise'); // Use promise-based MySQL client for better control

const app = express();
const port = 3000;

// Middleware to parse JSON bodies
app.use(bodyParser.json());

const defaultCfg = {
    host: 'localhost',
    user: 'root',
    password: 'root',
    database: 'test',
    supportBigNumbers: true,
    multipleStatements: true,
};

// Create a pool of connections for better performance
const pool = mysql.createPool(defaultCfg);

let isReady = false;

// Endpoint to check if the server is ready
app.get('/is_ready', (req, res) => {
    res.json({ ready: isReady });
});

// Function to handle query execution
async function executeQuery(query, parameters = []) {
    const [results] = await pool.execute(query, parameters);
    return results;
}

// POST /fetchAll endpoint
app.post('/fetchAll', async (req, res) => {
    try {
        const { query, params } = req.body;
        const results = await executeQuery(query, params);

        // Send results as JSON
        res.json(results);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /insert endpoint
app.post('/insert', async (req, res) => {
    try {
        const { query, params } = req.body;
        const results = await executeQuery(query, params);
        
        // Send only the insertId as JSON
        res.json({ insertId: results.insertId || 0 });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /execute endpoint
app.post('/execute', async (req, res) => {
    try {
        const { query, params } = req.body;

        if (!query) {
            return res.status(400).json({ error: 'No query provided' });
        }

        const results = await executeQuery(query, params);

        // Check if affectedRows is present
        if (results.affectedRows !== undefined) {
            res.json({ affectedRows: results.affectedRows });
        } else if (Array.isArray(results) && results.length > 0) {
            res.json(results); // Send the results as JSON
        } else {
            res.json({ message: 'No data available' });
        }
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/fetchScalar', async (req, res) => {
    try {
        const { query, params } = req.body;

        // Check if query exists
        if (!query) {
            return res.status(400).json({ error: 'No query provided' });
        }

        const results = await executeQuery(query, params);

        if (results.affectedRows !== undefined) {
            // Respond with affectedRows if present
            return res.json({ affectedRows: results.affectedRows });
        } else if (Array.isArray(results) && results.length > 0) {
            // Send the scalar value (first column of the first row)
            return res.json({ scalar: Object.values(results[0])[0] });
        } else {
            return res.json({ message: 'No data available' });
        }
    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});

// Start the server and mark it as ready
app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
    isReady = true;
});
