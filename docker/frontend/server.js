const express = require("express");

const app = express();
const port = Number(process.env.PORT || 3000);
const backendUrl = process.env.BACKEND_URL || "http://backend:5000";
const requestTimeoutMs = Number(process.env.BACKEND_TIMEOUT_MS || 5000);

app.disable("x-powered-by");
app.use(express.json({ limit: "32kb" }));
app.use(express.static("public"));

app.use((req, res, next) => {
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("X-Frame-Options", "DENY");
    next();
});

app.get("/health", (req, res) => {
    res.json({ status: "healthy", service: "frontend-ui", version: "v2.0.0" });
});

app.all(["/api/users", "/api/users/:id"], async (req, res) => {
    const targetUrl = new URL(req.originalUrl, backendUrl);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);

    const options = {
        method: req.method,
        signal: controller.signal,
        headers: {
            "content-type": "application/json"
        }
    };

    if (!["GET", "HEAD"].includes(req.method)) {
        options.body = JSON.stringify(req.body || {});
    }

    try {
        const response = await fetch(targetUrl, options);
        const contentType = response.headers.get("content-type") || "application/json";
        const body = await response.text();

        res.status(response.status).type(contentType);
        if (body) {
            res.send(body);
        } else {
            res.end();
        }
    } catch (error) {
        const timedOut = error.name === "AbortError";
        res.status(timedOut ? 504 : 502).json({
            error: timedOut ? "backend timeout" : "backend unavailable"
        });
    } finally {
        clearTimeout(timeout);
    }
});

const server = app.listen(port, () => {
    console.log(`Frontend UI service listening on port ${port}`);
});

function shutdown(signal) {
    console.log(`Received ${signal}, shutting down server gracefully`);
    server.close(() => process.exit(0));
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
