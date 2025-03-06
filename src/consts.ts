import {
  CUMARU_KEYS_ANTHROPIC_API_KEY,
  CUMARU_KEYS_GEMINI_API_KEY,
  CUMARU_LLM_PRE_PROMPT_REPLACE,
  CUMARU_LLM_POST_PROMPT_REPLACE,
  CUMARU_LLM_PRE_PROMPT_APPEND,
  CUMARU_LLM_POST_PROMPT_APPEND,
} from "@/config";

export const anthroipcApiKey = CUMARU_KEYS_ANTHROPIC_API_KEY ?? "";
export const geminiApiKey = CUMARU_KEYS_GEMINI_API_KEY ?? "";

const defaultPrePrompt = `
Create a function that follows the parameters below. Respond with only the function.

Build a JSON with the parameters of: "name" as string, "body" as a string and "parameters", as an array of strings, example:

{
  "name": "substractNumbers",
  "body": "return a - b;",
  "parameters": ["a", "b"]
}

This JSON will create a standard paramters for the "new Function()" class locally to parse it as a real function.
`;
export const prePrompt: string = `${
  Boolean(CUMARU_LLM_PRE_PROMPT_REPLACE)
    ? `${CUMARU_LLM_PRE_PROMPT_REPLACE}`
    : defaultPrePrompt
} ${CUMARU_LLM_PRE_PROMPT_APPEND}`;

const defaultPostPrompt = `
Do not output nothing else, no explanations, no video. No console logs or tests are necessary.

Do not use restricted values.

The variables expressed in these prompts are just examples; Only commit to maintaining their type, not their actual value.

Follow best practices for function construction for Typesceript and Javascript, consider strict linter rules.

Keep in mind, the focus is to use this output as a separate TypeScript file/module.

Do not use blocks of code.

Do not use comments.

Do not use triple quotes.

RESPECT THE JSON STRUCTURE.
`;
export const postPrompt: string = `${
  Boolean(CUMARU_LLM_POST_PROMPT_REPLACE)
    ? `${CUMARU_LLM_POST_PROMPT_REPLACE}`
    : defaultPostPrompt
} ${CUMARU_LLM_POST_PROMPT_APPEND}`;
