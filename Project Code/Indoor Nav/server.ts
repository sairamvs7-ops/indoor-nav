import express from "express";
import { createServer as createViteServer } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = 3000;

  // Proxy route for ESP32
  // This avoids Mixed Content (HTTPS -> HTTP) and CORS issues in the browser
  app.get("/api/node", async (req, res) => {
    const { current, destination } = req.query;
    const ESP32_IP = "192.168.4.1";
    const targetUrl = `http://${ESP32_IP}/node?current=${current}&destination=${destination}`;

    console.log(`Proxying request to ESP32: ${targetUrl}`);

    try {
      const response = await fetch(targetUrl, {
        method: 'GET',
        signal: AbortSignal.timeout(5000), // 5 second timeout
      });

      if (!response.ok) {
        return res.status(response.status).json({ error: `ESP32 returned ${response.status}` });
      }

      const data = await response.json();
      res.json(data);
    } catch (error: any) {
      console.error("Proxy Error:", error.message);
      res.status(502).json({ 
        error: "ESP32 Unreachable via Proxy", 
        details: error.message 
      });
    }
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
