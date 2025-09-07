//date: Date;
// utils/dates.ts (or top of the router file)
export function toISOStringNoMillis(d: Date): string {
  // "2024-12-30T12:00:00.000Z" -> "2024-12-30T12:00:00Z"
  return d.toISOString().replace(/\.\d{3}Z$/, "Z");
}
