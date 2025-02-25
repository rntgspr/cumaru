import crypto from "node:crypto";

import logger from "@/logger";

/**
 * Creates a unique cache ID for a given prompt using MD5 hash
 *
 * @param prompt - The prompt string to create a cache ID for
 * @returns MD5 hash of the prompt as a hex string
 *
 * @example
 * const id = createCacheId("my prompt")
 * // id = "a4f1b60714d0c64f43d2f3046666c5cc"
 */
export function createCacheId(prompt: string): string {
  const cacheId = crypto.createHash("md5").update(prompt).digest("hex");
  logger.debug(`Cumaru cache id: ${cacheId}`);
  return cacheId;
}
