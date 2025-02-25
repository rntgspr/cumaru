import { checkCache } from "@/data/check-cache";
import { buildFunction } from "@/data/build-function";
import { createCacheId } from "@/data/create-cache-id";
import { flatTemplateString } from "@/data/flat-template-string";
import { writeCacheToDisk } from "@/data/write-cache-to-disk";
import { writeFunctionToDisk } from "@/data/write-function-to-disk";
import { askLLM } from "@/io/ask-llm";

export async function cumaru<T>(
  strings: TemplateStringsArray,
  ...values: Array<any>
): Promise<T | undefined> {
  // flat template string
  const prompt = flatTemplateString(strings, values);

  // create cache id
  const cacheId = createCacheId(prompt);

  // check cache
  const cached = await checkCache(cacheId);
  if (cached) {
    return cached as T;
  }

  // ask LLM
  const parsed = await askLLM(prompt);

  // build function
  const { logicalOutput, stringOutput } = buildFunction(parsed);

  // write function to disk
  const pathname = await writeFunctionToDisk(parsed.name, stringOutput);

  // write cache to disk
  await writeCacheToDisk(cacheId, pathname);

  // return logical output
  return logicalOutput as T;
}
