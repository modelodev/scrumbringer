#!/usr/bin/env node

import fs from "node:fs";

const BASE_ENV = "SCRUMBRINGER_BASE_URL";
const TOKEN_ENV = "SCRUMBRINGER_API_TOKEN";

function usage() {
  console.log(`Usage:
  node docs/skill/scripts/scrumbringer-api.mjs preflight [EXTRA_ENV...]
  node docs/skill/scripts/scrumbringer-api.mjs get PATH
  node docs/skill/scripts/scrumbringer-api.mjs post PATH JSON_OR_@FILE
  node docs/skill/scripts/scrumbringer-api.mjs patch PATH JSON_OR_@FILE
  node docs/skill/scripts/scrumbringer-api.mjs put PATH [JSON_OR_@FILE]
  node docs/skill/scripts/scrumbringer-api.mjs delete PATH [JSON_OR_@FILE]
  node docs/skill/scripts/scrumbringer-api.mjs request METHOD PATH [JSON_OR_@FILE]

Required env:
  ${BASE_ENV}
  ${TOKEN_ENV}
`);
}

function fail(message, code = 1) {
  console.error(message);
  process.exit(code);
}

function requireEnv(names) {
  const missing = names.filter((name) => !process.env[name]);
  if (missing.length > 0) {
    fail(`Missing required env: ${missing.join(", ")}`);
  }
}

function redactToken(token) {
  if (token.length <= 12) return "<redacted>";
  return `${token.slice(0, 8)}...${token.slice(-4)}`;
}

function normalizedBaseUrl() {
  const value = process.env[BASE_ENV];
  return value.replace(/\/+$/, "");
}

function endpoint(path) {
  if (!path.startsWith("/api/v1/") && path !== "/api/v1/projects") {
    fail(`Path must start with /api/v1/: ${path}`);
  }
  return `${normalizedBaseUrl()}${path}`;
}

function readBody(value) {
  if (value === undefined) return undefined;
  const raw = value.startsWith("@")
    ? fs.readFileSync(value.slice(1), "utf8")
    : value;

  try {
    JSON.parse(raw);
  } catch (error) {
    fail(`Invalid JSON body: ${error.message}`);
  }

  return raw;
}

async function request(method, path, bodyArg) {
  requireEnv([BASE_ENV, TOKEN_ENV]);

  const body = readBody(bodyArg);
  const headers = {
    Authorization: `Bearer ${process.env[TOKEN_ENV]}`,
    Accept: "application/json",
  };

  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
  }

  const response = await fetch(endpoint(path), {
    method,
    headers,
    body,
  });

  const text = await response.text();
  const contentType = response.headers.get("content-type") || "";
  let output = text;

  if (text && contentType.includes("application/json")) {
    try {
      output = JSON.stringify(JSON.parse(text), null, 2);
    } catch {
      output = text;
    }
  }

  if (output) {
    console.log(output);
  }

  if (!response.ok) {
    process.exit(response.status || 1);
  }
}

async function main() {
  const [command, ...args] = process.argv.slice(2);

  if (!command || command === "help" || command === "--help") {
    usage();
    return;
  }

  if (command === "preflight") {
    requireEnv([BASE_ENV, TOKEN_ENV, ...args]);
    console.log(JSON.stringify({
      ok: true,
      base_url: normalizedBaseUrl(),
      token: redactToken(process.env[TOKEN_ENV]),
      extra_env_checked: args,
    }, null, 2));
    return;
  }

  const aliases = {
    get: "GET",
    post: "POST",
    patch: "PATCH",
    put: "PUT",
    delete: "DELETE",
  };

  if (command === "request") {
    const [method, path, body] = args;
    if (!method || !path) {
      usage();
      fail("request requires METHOD and PATH");
    }
    await request(method.toUpperCase(), path, body);
    return;
  }

  if (Object.hasOwn(aliases, command)) {
    const [path, body] = args;
    if (!path) {
      usage();
      fail(`${command} requires PATH`);
    }
    await request(aliases[command], path, body);
    return;
  }

  usage();
  fail(`Unknown command: ${command}`);
}

main().catch((error) => {
  fail(error.stack || error.message || String(error));
});
