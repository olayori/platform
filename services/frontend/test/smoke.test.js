"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const html = fs.readFileSync(path.join(root, "src", "index.html"), "utf8");
const appJs = fs.readFileSync(path.join(root, "src", "app.js"), "utf8");
const nginxConf = fs.readFileSync(path.join(root, "nginx.conf"), "utf8");

test("index.html has the expected title", () => {
  assert.match(html, /<title>Adowol Platform Demo<\/title>/);
  assert.match(html, /Adowol Platform Demo/);
});

test("index.html wires up app.js and the output cards", () => {
  assert.match(html, /app\.js/);
  assert.match(html, /id="hello-output"/);
  assert.match(html, /id="time-output"/);
  assert.match(html, /id="refresh"/);
});

test("app.js references both backend endpoints", () => {
  assert.match(appJs, /\/api\/hello/);
  assert.match(appJs, /\/api\/time/);
});

test("app.js uses fetch and handles errors", () => {
  assert.match(appJs, /fetch\(/);
  assert.match(appJs, /catch/);
});

test("nginx.conf listens on 8080 and exposes /healthz", () => {
  assert.match(nginxConf, /listen\s+8080/);
  assert.match(nginxConf, /location\s*=\s*\/healthz/);
  assert.match(nginxConf, /return 200 'ok'/);
  assert.match(nginxConf, /try_files/);
  assert.match(nginxConf, /gzip on/);
});
