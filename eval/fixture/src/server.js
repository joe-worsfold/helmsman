import { parseQuery } from "./parse.js";

export function handle(method, path, query) {
  if (method === "GET" && path === "/health") {
    const parsed = parseQuery([], query);
    return { status: 200, body: { ok: true, query: parsed } };
  }
  return { status: 404, body: { error: "not_found" } };
}
