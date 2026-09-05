export type RecordData = { kills: number; cleared: boolean };
const KEY = "hokori-best-v1";
export function bestRecord(read = () => localStorage.getItem(KEY)): RecordData {
  try {
    const d = JSON.parse(read() ?? "null");
    return {
      kills:
        Number.isSafeInteger(d?.kills) && d.kills >= 0 && d.kills <= 1_000_000
          ? d.kills
          : 0,
      cleared: d?.cleared === true,
    };
  } catch {
    return { kills: 0, cleared: false };
  }
}
export function saveRecord(
  record: RecordData,
  write = (value: string) => localStorage.setItem(KEY, value),
): boolean {
  try {
    write(JSON.stringify(record));
    return true;
  } catch {
    return false;
  }
}
