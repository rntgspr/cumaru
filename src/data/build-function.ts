import { ParsedResults } from "@/types";

export function buildFunction(parsed: ParsedResults) {
  const logicalOutput: Function = new Function(
    ...parsed.parameters,
    parsed.body
  );

  const regex = /^function\s+([a-zA-Z_$][\w$]*)\s*\(/;
  const stringOutput = logicalOutput
    .toString()
    .replace(regex, `function ${parsed.name}(`);

  return { logicalOutput, stringOutput, parsed };
}
