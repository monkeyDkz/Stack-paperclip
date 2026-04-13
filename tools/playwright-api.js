const http = require("http");
const { execSync, exec } = require("child_process");
const fs = require("fs");
const path = require("path");

const PORT = 3333;
const SCRIPTS_DIR = "/tests/scripts";
const RESULTS_DIR = "/results";

// Ensure dirs exist
fs.mkdirSync(SCRIPTS_DIR, { recursive: true });
fs.mkdirSync(RESULTS_DIR, { recursive: true });

const server = http.createServer((req, res) => {
  // CORS
  res.setHeader("Content-Type", "application/json");

  if (req.method === "GET" && req.url === "/health") {
    return res.end(JSON.stringify({ status: "ok", service: "playwright-api" }));
  }

  if (req.method === "POST" && req.url === "/run") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const { script, env, timeout } = JSON.parse(body);
        if (!script) {
          res.statusCode = 400;
          return res.end(JSON.stringify({ error: "script field required" }));
        }

        // Write script to temp file
        const scriptId = `task-${Date.now()}`;
        const scriptPath = path.join(SCRIPTS_DIR, `${scriptId}.js`);
        const resultPath = path.join(RESULTS_DIR, `${scriptId}.json`);
        fs.writeFileSync(scriptPath, script);

        // Build env vars
        const execEnv = { ...process.env, RESULT_PATH: resultPath };
        if (env) Object.assign(execEnv, env);

        // Execute with timeout (default 60s)
        const maxTimeout = Math.min(timeout || 60000, 300000);
        const child = exec(`node ${scriptPath}`, {
          env: execEnv,
          timeout: maxTimeout,
          maxBuffer: 10 * 1024 * 1024,
        });

        let stdout = "";
        let stderr = "";
        child.stdout.on("data", (d) => (stdout += d));
        child.stderr.on("data", (d) => (stderr += d));

        child.on("close", (code) => {
          // Read result file if it exists
          let result = null;
          try {
            if (fs.existsSync(resultPath)) {
              result = JSON.parse(fs.readFileSync(resultPath, "utf-8"));
            }
          } catch (e) {}

          // Cleanup
          try { fs.unlinkSync(scriptPath); } catch (e) {}
          try { if (fs.existsSync(resultPath)) fs.unlinkSync(resultPath); } catch (e) {}

          res.end(JSON.stringify({
            exitCode: code,
            stdout: stdout.slice(-5000),
            stderr: stderr.slice(-2000),
            result,
          }));
        });
      } catch (e) {
        res.statusCode = 500;
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  if (req.method === "POST" && req.url === "/eval") {
    // Simple page evaluation — no full script needed
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const { url, extract } = JSON.parse(body);
        if (!url) {
          res.statusCode = 400;
          return res.end(JSON.stringify({ error: "url field required" }));
        }

        const evalScript = `
const { chromium } = require("playwright");
const fs = require("fs");
(async () => {
  const browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
  const page = await (await browser.newContext()).newPage();
  await page.route("**/*.{png,jpg,jpeg,gif,woff,woff2,mp4,svg}", r => r.abort());
  try {
    await page.goto(${JSON.stringify(url)}, { waitUntil: "domcontentloaded", timeout: 15000 });
  } catch(e) {
    fs.writeFileSync(process.env.RESULT_PATH, JSON.stringify({ url: ${JSON.stringify(url)}, error: "unreachable: " + e.message }));
    await browser.close();
    return;
  }
  const html = await page.content();
  const text = await page.evaluate(() => document.body?.innerText || "");
  const title = await page.title();
  const imgCount = await page.evaluate(() => document.querySelectorAll("img").length);
  const hasForm = await page.evaluate(() => !!document.querySelector("form"));
  const links = await page.evaluate(() => Array.from(document.querySelectorAll("a[href]")).map(a => a.href).slice(0, 50));
  const meta = await page.evaluate(() => {
    const m = {};
    document.querySelectorAll("meta").forEach(el => {
      const name = el.getAttribute("name") || el.getAttribute("property") || "";
      if (name) m[name] = el.getAttribute("content") || "";
    });
    return m;
  });
  fs.writeFileSync(process.env.RESULT_PATH, JSON.stringify({
    url: ${JSON.stringify(url)},
    title,
    protocol: ${JSON.stringify(url)}.startsWith("https") ? "HTTPS" : "HTTP",
    imgCount,
    hasForm,
    html_length: html.length,
    text_length: text.length,
    links_count: links.length,
    meta,
    copyright_match: (html.match(/(?:©|&copy;|copyright)\\s*(\\d{4})/i) || [])[1] || null,
    generator: (html.match(/generator.*?content="([^"]+)"/i) || [])[1] || null,
    builder_hints: {
      emonsite: html.includes("e-monsite"),
      jimdo: html.includes("jimdo"),
      free_fr: ${JSON.stringify(url)}.includes(".free.fr"),
      wordpress: /wp-content|wordpress/i.test(html),
      wix: /wix/i.test(html),
    },
    text_preview: text.slice(0, 500),
  }));
  await browser.close();
})();
`;
        // Write and execute
        const scriptId = `eval-${Date.now()}`;
        const scriptPath = `/tests/scripts/${scriptId}.js`;
        const resultPath = `/results/${scriptId}.json`;
        fs.writeFileSync(scriptPath, evalScript);

        exec(`node ${scriptPath}`, {
          env: { ...process.env, RESULT_PATH: resultPath },
          timeout: 30000,
        }, (err, stdout, stderr) => {
          let result = null;
          try {
            if (fs.existsSync(resultPath)) {
              result = JSON.parse(fs.readFileSync(resultPath, "utf-8"));
            }
          } catch (e) {}
          try { fs.unlinkSync(scriptPath); } catch (e) {}
          try { if (fs.existsSync(resultPath)) fs.unlinkSync(resultPath); } catch (e) {}
          res.end(JSON.stringify({ result, error: err ? err.message : null }));
        });
      } catch (e) {
        res.statusCode = 500;
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  res.statusCode = 404;
  res.end(JSON.stringify({ error: "Not found. Use GET /health, POST /run, or POST /eval" }));
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Playwright API listening on :${PORT}`);
});
