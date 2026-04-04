const http = require("http");
const LISTEN_PORT = parseInt(process.argv[2] || "11435", 10);
const OLLAMA_PORT = parseInt(process.argv[3] || "11434", 10);
const OLLAMA_HOST = "127.0.0.1";

const server = http.createServer((req, res) => {
  const ts = new Date().toISOString();
  console.log(`[${ts}] ${req.method} ${req.url}`);
  const chunks = [];
  req.on("data", (chunk) => chunks.push(chunk));
  req.on("end", () => {
    let body = Buffer.concat(chunks);
    if (req.url === "/api/chat" && req.method === "POST") {
      try {
        const parsed = JSON.parse(body.toString());
        const msgSizes = (parsed.messages || []).map(
          (m) => `${m.role}:${(m.content || "").length}chars`,
        );
        console.log(
          `  model=${parsed.model} think=${parsed.think} stream=${parsed.stream} num_ctx=${parsed.options?.num_ctx}`,
        );
        console.log(`  messages(${parsed.messages?.length}): ${msgSizes.join(", ")}`);
        parsed.think = false;
        body = Buffer.from(JSON.stringify(parsed));
      } catch (e) {
        console.log(`  parse error: ${e.message}`);
      }
    }
    const start = Date.now();
    const proxyReq = http.request(
      {
        hostname: OLLAMA_HOST,
        port: OLLAMA_PORT,
        path: req.url,
        method: req.method,
        headers: {
          ...req.headers,
          host: `${OLLAMA_HOST}:${OLLAMA_PORT}`,
          "content-length": body.length,
        },
      },
      (proxyRes) => {
        console.log(`  <- ${proxyRes.statusCode} (${((Date.now() - start) / 1000).toFixed(1)}s)`);
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res);
      },
    );
    proxyReq.on("error", (err) => {
      console.error(`  <- error: ${err.message}`);
      res.writeHead(502);
      res.end("Bad Gateway");
    });
    proxyReq.end(body);
  });
});
server.listen(LISTEN_PORT, "0.0.0.0", () => {
  console.log(`Proxy: 0.0.0.0:${LISTEN_PORT} -> ${OLLAMA_HOST}:${OLLAMA_PORT}`);
});
