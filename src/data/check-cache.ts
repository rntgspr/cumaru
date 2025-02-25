import path from "node:path";

import { getOrCreateCache } from "@/data/get-or-create-cache";
import logger from "@/logger";

export async function checkCache(cacheId: string) {
  const cache = await getOrCreateCache();

  if (cache?.[cacheId]) {
    logger.debug(`Cache hit, id:${cacheId}, file: ${cache?.[cacheId]}`);

    const filePath = path.resolve(process.cwd(), cache[cacheId]);
    const result = await import(filePath);
    const functionName = Object.keys(result)?.[0];
    if (functionName) {
      return result[functionName];
    }
  }

  return undefined;
}
