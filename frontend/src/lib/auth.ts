export function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT");
  let payload = parts[1]!;
  const pad = 4 - (payload.length % 4);
  if (pad !== 4) payload += "=".repeat(pad);
  return JSON.parse(atob(payload));
}
