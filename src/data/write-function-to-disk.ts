import fs from "fs/promises";
import { nanoid } from "nanoid";

import { createCacheDir } from "@/data/create-cache-dir";
import { CUMARU_CACHE_DIR, CUMARU_FILE_PREFIX } from "@/config";
import logger from "@/logger";

/**
 * Creates a unique nano ID prefixed with the configured file prefix.
 * Uses nanoid to generate an 8 character random string.
 *
 * @returns A string in the format `{CUMARU_FILE_PREFIX}_{nanoid(8)}`
 */
function createNanoId() {
  const nId = nanoid(8);
  return `${CUMARU_FILE_PREFIX}_${nId}`;
}

/**
 * Writes a function to a file.
 *
 * @param pathname - The path to the file.
 * @param data - The data to write to the file.
 * @returns The path to the file.
 */
async function createFunctionFile(pathname: string, data: string) {
  const dataWithExport = `export ${data}`;
  await fs.writeFile(pathname, dataWithExport, { encoding: "utf8" });
  return pathname;
}

/**
 * Writes a function to a file.
 *
 * @param name - The name of the function.
 * @param data - The data to write to the file.
 * @returns The path to the file.
 */
export async function writeFunctionToDisk(name: string, data: string) {
  await createCacheDir();

  const nId = createNanoId();
  logger.silly(`File nanoId: ${nId}`);

  const pathname = `${CUMARU_CACHE_DIR}/${nId}_${name}.js`;
  logger.silly(`File pathname: ${pathname}`);

  await createFunctionFile(pathname, data);
  return pathname;
}
