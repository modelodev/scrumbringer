import http from "node:http";

const port = Number(process.env.PORT || process.env.SB_PORT || 9000);

const json = (res, status, body) => {
  const bytes = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": String(bytes.length),
    "cache-control": "no-store",
  });
  res.end(bytes);
};

const notFound = (res) => {
  json(res, 404, { error: "not_found" });
};

const user = {
  id: 1,
  email: "smoke-admin@example.com",
  org_id: 1,
  org_role: "Admin",
  created_at: "2026-01-14T00:00:00Z",
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", "http://localhost");
  const path = url.pathname;

  // Minimal endpoints to satisfy Story 2.7 smoke scenario.
  if (req.method === "GET" && path === "/api/v1/auth/me") {
    return json(res, 200, { user });
  }

  if (req.method === "GET" && path === "/api/v1/projects") {
    return json(res, 200, {
      projects: [{ id: 2, name: "Project 2", my_role: "admin" }],
    });
  }

  if (req.method === "GET" && path === "/api/v1/capabilities") {
    return json(res, 200, {
      capabilities: [{ id: 1, name: "Capability 1" }],
    });
  }

  if (req.method === "GET" && path === "/api/v1/me/capabilities") {
    return json(res, 200, { capability_ids: [1] });
  }

  if (req.method === "GET" && path === "/api/v1/org/invite-links") {
    return json(res, 200, { invite_links: [] });
  }

  if (req.method === "GET" && path === "/api/v1/org/users") {
    return json(res, 200, {
      users: [
        {
          id: user.id,
          email: user.email,
          org_role: user.org_role,
          created_at: user.created_at,
        },
      ],
    });
  }

  if (req.method === "GET" && path === "/api/v1/projects/2/members") {
    return json(res, 200, {
      members: [{ user_id: user.id, role: "admin", created_at: user.created_at }],
    });
  }

  return notFound(res);
});

server.listen(port, "127.0.0.1", () => {
  // eslint-disable-next-line no-console
  console.log(`mock api 2.7 listening on http://127.0.0.1:${port}`);
});
