import logger from "@/logger";

/**
 * Combines a template string with its values into a single flat string
 *
 * @param strings - Array of strings from the template literal
 * @param values - Array of values to be interpolated
 * @returns Flat string combining the template with values
 *
 * @example
 * const result = flatTemplateString`Hello ${name}!`
 * // result = 'Hello "John"!'
 */
export function flatTemplateString(
  strings: TemplateStringsArray,
  values: Array<any>
) {
  try {
    const flatted = strings.reduce((acc, item, index) => {
      let nextAcc = acc;
      nextAcc += item;
      if (index < values.length) {
        nextAcc += String(JSON.stringify(values[index]));
      }
      return nextAcc;
    });

    logger.silly(`Function prompt:\n${flatted}`);
    return flatted;
  } catch (error) {
    logger.error("Error in flatTemplateString:", error);
    throw error;
  }
}
