import { getCache } from "@/data/get-cache";
import { ExtendedError, CumaruCache } from "@/index";
import { saveCache } from "@/data/save-cache";

export async function getOrCreateCache(): Promise<CumaruCache> {
  let rawCache;

  try {
    rawCache = await getCache();
  } catch (error: unknown) {
    if ((error as ExtendedError)?.code === "ENOENT") {
      await saveCache({});
      rawCache = await getCache();
    } else {
      throw error as ExtendedError;
    }
  }

  return JSON.parse(rawCache?.toString());
}
