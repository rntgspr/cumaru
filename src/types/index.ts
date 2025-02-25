import Anthropic from "@anthropic-ai/sdk";
import { GenerateContentResult } from "@google/generative-ai";

export type ParsedResults = {
  name: string;
  parameters: string[];
  body: string;
};

export type Asker<T> = (message: string) => Promise<T>;
export type Commiter<T> = (response: T) => string;
export type Parser = (unparsed: string) => ParsedResults;

type LLMMessageMap = {
  anthropic: Anthropic.Messages.Message;
  gemini: GenerateContentResult;
  openai: any;
};
export type LLMOptions = keyof LLMMessageMap;
export type LLMChoices = {
  [K in LLMOptions]?: {
    ask: Asker<LLMMessageMap[K]>;
    commitResponse: Commiter<LLMMessageMap[K]>;
    parse: Parser;
  };
};
