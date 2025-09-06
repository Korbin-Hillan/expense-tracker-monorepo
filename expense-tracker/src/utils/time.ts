export function toISODateInTZ(d: Date, timeZone: string): string {
  // Format a date to yyyy-mm-dd in a specific IANA time zone
  try {
    const fmt = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' });
    // en-CA gives YYYY-MM-DD
    return fmt.format(d);
  } catch {
    // Fallback to UTC
    return d.toISOString().slice(0, 10);
  }
}

export function nowISOInTZ(timeZone: string): string {
  return toISODateInTZ(new Date(), timeZone);
}
