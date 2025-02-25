import fs from "fs/promises";

import { CUMARU_CACHE_DIR, CUMARU_CACHE_FILE } from "@/config";
import { createCacheDir } from "@/data/create-cache-dir";
import { CumaruCache, ExtendedError } from "@/index";

export async function saveCache(cache: CumaruCache) {
  try {
    await createCacheDir();
    await fs.writeFile(
      `${CUMARU_CACHE_DIR}/${CUMARU_CACHE_FILE}`,
      JSON.stringify(cache, null, 2)
    );
  } catch (error) {
    throw error as ExtendedError;
  }
}
