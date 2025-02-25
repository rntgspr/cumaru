import { getOrCreateCache } from "@/data/get-or-create-cache";
import { saveCache } from "@/data/save-cache";

/**
 * Writes the cache to disk.
 *
 * @param cacheId - The cache ID.
 * @param path - The path to the cache.
 * @returns The cache ID.
 */
export async function writeCacheToDisk(cacheId: string, path: string) {
  const cache = await getOrCreateCache();
  cache[cacheId] = path;

  await saveCache(cache);

  return cache[cacheId];
}
