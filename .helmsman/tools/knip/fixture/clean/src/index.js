import { tax } from "./tax.js";

export function pay(amount) {
  return tax(amount, 0.2);
}
