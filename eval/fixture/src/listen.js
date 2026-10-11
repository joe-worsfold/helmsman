export function listenPort() {
  return Number(process.env.PORT ?? 3000);
}

export function bind(server) {
  return server.listen(3000);
}

export function banner() {
  if (process.env.FEATURE_BANNER !== "on") return "";
  return "ahoy";
}
