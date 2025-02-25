import { LLMChoices, LLMOptions, ParsedResults } from "../types";
import { CUMARU_LLM_CHOICE } from "../config";

import {
  askAnthropic,
  commitResponseAnthropic,
  parseAnthropic,
} from "./anthropic";
import { askGemini, commitResponseGemini, parseGemini } from "./gemini";

const llmChoices: LLMChoices = {
  anthropic: {
    ask: askAnthropic,
    commitResponse: commitResponseAnthropic,
    parse: parseAnthropic,
  },
  gemini: {
    ask: askGemini,
    commitResponse: commitResponseGemini,
    parse: parseGemini,
  },
};

export async function askLLM(prompt: string): Promise<ParsedResults> {
  const llmChoiceName = CUMARU_LLM_CHOICE as LLMOptions;
  const llmChoice = llmChoices[llmChoiceName];

  if (!llmChoice) {
    throw new Error("LLMChoice not found");
  }

  const response = await llmChoice.ask(prompt);
  const unparsed = llmChoice.commitResponse(response);
  const parsed = llmChoice.parse(unparsed);

  return parsed;
}
