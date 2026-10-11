// Text and status from a failed child process. Pure. No I/O.

/** @param {unknown} err */
export function failureText(err) {
  if (typeof err === "object" && err !== null && "stderr" in err) {
    const stderr = err.stderr;
    if (typeof stderr === "string" && stderr !== "") return stderr;
    if (stderr instanceof Uint8Array && stderr.byteLength > 0) return Buffer.from(stderr).toString();
  }
  if (err instanceof Error && err.message !== "") return err.message;
  return String(err);
}

/** @param {unknown} err */
export function exitStatus(err) {
  if (typeof err === "object" && err !== null && "status" in err) {
    if (typeof err.status === "number") return err.status;
  }
  return null;
}
