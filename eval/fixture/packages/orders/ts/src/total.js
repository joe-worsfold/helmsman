export function orderTotal(lines) {
  return lines.reduce((sum, line) => sum + line.amount, 0);
}
