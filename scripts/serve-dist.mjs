import { createReadStream, existsSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { createServer } from "node:http";

const root = join(process.cwd(), "frontend", "dist");
const port = Number(process.env.PORT ?? 4173);

const types = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml"
};

createServer((request, response) => {
  const rawPath = new URL(request.url ?? "/", `http://${request.headers.host}`).pathname;
  const safePath = normalize(decodeURIComponent(rawPath)).replace(/^(\.\.[/\\])+/, "");
  const requested = join(root, safePath === "/" ? "index.html" : safePath);
  const filePath = existsSync(requested) ? requested : join(root, "index.html");

  response.setHeader("Content-Type", types[extname(filePath)] ?? "application/octet-stream");
  createReadStream(filePath)
    .on("error", () => {
      response.statusCode = 404;
      response.end("Not found");
    })
    .pipe(response);
}).listen(port, "127.0.0.1", () => {
  console.log(`InfraReaper preview running at http://127.0.0.1:${port}`);
});

