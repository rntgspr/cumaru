import { mkdirp } from "mkdirp";

import { CUMARU_CACHE_DIR } from "@/config";

export async function createCacheDir() {
  try {
    await mkdirp(CUMARU_CACHE_DIR);
  } catch (error) {
    throw error;
  }
}
