import express from 'express';
const app = express();

import http from 'http';
const server = http.createServer(app);

// ---- SETUP .ENV ----

import path from 'path';
import { fileURLToPath } from 'url';

import dotenv from 'dotenv';
dotenv.config({path: path.join(path.dirname(fileURLToPath(import.meta.url)), ".env")});

// ---- MIDDLEWARE ----

app.set('trust proxy', true);

import bodyParser from 'body-parser';
app.use(bodyParser.json());

// ---- RUN SERVER PROCESSES ----

import cluster from 'node:cluster'
import { availableParallelism } from 'node:os';

const numCPUs = availableParallelism();
const port = process.env.PORT || 5000;

if (cluster.isPrimary) {
    console.log(`Server started on port: ${port} (${new Date()})`);

    // ---- FORK WORKERS ----

    let workers = process.env.WORKERS || 1;
    workers = parseInt(workers);

    if (workers > numCPUs) workers = numCPUs;

    for (let i = 0; i < workers; i++) {
        cluster.fork();
    }

    cluster.on('exit', (worker, code, signal) => {
        cluster.fork();
    });
} else {

    // ---- ROUTES ----

    app.post('/log', (req, res) => {
        const { content } = req.body;
        console.log(content);

        res.status(200).send();
    });

    // ---- START SERVER ----

    server.listen(port, () => {
        console.log(`Worker is running: ${process.pid}`);
    });
}