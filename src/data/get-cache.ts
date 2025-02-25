import fs from "fs/promises";

import { createCacheDir } from "@/data/create-cache-dir";
import { CUMARU_CACHE_DIR, CUMARU_CACHE_FILE } from "@/config";
import { ExtendedError } from "@/index";

export async function getCache(): Promise<string> {
  try {
    await createCacheDir();
    const rawCache = await fs.readFile(
      `${CUMARU_CACHE_DIR}/${CUMARU_CACHE_FILE}`
    );

    return rawCache.toString();
  } catch (error) {
    throw error as ExtendedError;
  }
}
