#!/usr/bin/env bash
# Serve the built static site in the foreground on PORT (default 3000).
# Writes deployment-output.json for the controller. Keep source and build
# output inside PROJECT_DIR; OPENCODE_WEB_DIR/RUNNER_TEMP hold only metadata.
set -euo pipefail
time -p cd "$(dirname "$0")"
/usr/bin/time -p pwd
PROJECT_DIR="$(/usr/bin/time -p pwd)"
export PROJECT_DIR
/usr/bin/time -p test -f "$PROJECT_DIR/dist/index.html"
# Install dependencies when a package project is present (conditional build).
if /usr/bin/time -p test -f "$PROJECT_DIR/package.json"; then
  if /usr/bin/time -p test -f "$PROJECT_DIR/package-lock.json"; then
    /usr/bin/time -p npm ci --no-audit --no-fund
  else
    /usr/bin/time -p npm install --no-audit --no-fund
  fi
  if /usr/bin/time -p npm run | grep -q " build"; then
    /usr/bin/time -p npm run build
  fi
  /usr/bin/time -p test -f "$PROJECT_DIR/dist/index.html"
fi
PORT="${PORT:-3000}"
export PORT
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
export WEB_DIR
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p node -e 'const fs=require("node:fs"),path=require("node:path");const project=process.env.PROJECT_DIR||process.cwd();const dir=path.resolve(project,"dist");const web=process.env.WEB_DIR;fs.mkdirSync(web,{recursive:true});fs.writeFileSync(path.join(web,"deployment-output.json"),JSON.stringify({project,directory:dir}));console.log("deployment-output:",JSON.stringify({project,directory:dir}));'
# Serve the built directory in the foreground (no daemonizing).
exec /usr/bin/time -p node -e '
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(process.env.PROJECT_DIR || process.cwd(), "dist");
const port = Number(process.env.PORT || 3000);
const mime = { ".html": "text/html; charset=utf-8", ".js": "application/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".json": "application/json", ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".ico": "image/x-icon", ".woff2": "font/woff2" };
const server = http.createServer((req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    let p = decodeURIComponent(url.pathname);
    if (p.endsWith("/")) p += "index.html";
    const file = path.resolve(root, "." + p);
    if (file !== root && !file.startsWith(root + path.sep)) { res.writeHead(404); res.end("Not found"); return; }
    const st = fs.statSync(file);
    const target = st.isDirectory() ? path.join(file, "index.html") : file;
    res.setHeader("Content-Type", mime[path.extname(target).toLowerCase()] || "application/octet-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.end(fs.readFileSync(target));
  } catch { res.writeHead(404); res.end("Not found"); }
});
server.listen(port, "0.0.0.0", () => console.log("Serving " + root + " on port " + port));
'
