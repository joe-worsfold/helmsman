// Parse the flake quarantine list. Pure. A line without an issue URL is an error.

/** @param {string} text */
export function readQuarantine(text) {
  const rows = [];
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i].trim();
    if (raw === "" || raw.startsWith("#")) continue;
    const parts = raw.split(/\s+/);
    const id = parts[0] ?? "";
    const url = parts[1] ?? "";
    if (id === "" || url === "") {
      throw new Error(`quarantine line ${i + 1} needs a scenario id and an issue URL`);
    }
    if (!/^https?:\/\//.test(url)) {
      throw new Error(`quarantine line ${i + 1} needs an http(s) issue URL`);
    }
    rows.push({ id, url });
  }
  return rows;
}
