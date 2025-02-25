import { ParsedResults } from "@/types";

export function parseAnthropic(uparsed: string): ParsedResults {
  const parsed: any = JSON.parse(uparsed);
  return parsed;
}
