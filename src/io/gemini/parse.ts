import { ParsedResults } from "@/types";
import logger from "../../logger";

export function parseGemini(uparsed: string): ParsedResults {
  const cleaned = uparsed.replace(/```json/g, "").replace(/```/g, "");
  logger.info("cleaned", cleaned);
  const parsed: any = JSON.parse(cleaned);
  return parsed;
}
