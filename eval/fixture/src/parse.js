// Untrusted input is parsed once. Callers take the parsed object.
export function parseQuery(fields, query) {
  const parsed = {};
  for (const field of fields) {
    const value = query[field.name];
    if (field.required && (value === undefined || value === "")) {
      throw new Error(`missing ${field.name}`);
    }
    if (value === undefined) continue;
    if (field.kind === "id" && !/^[A-Za-z0-9_-]{1,64}$/.test(value)) {
      throw new Error(`invalid ${field.name}`);
    }
    parsed[field.name] = value;
  }
  return parsed;
}
