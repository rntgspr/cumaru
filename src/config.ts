import "dotenv/config";

// log
export const CUMARU_LOG_LEVEL = process.env["CUMARU_LOG_LEVEL"] ?? "debug";

// cache
export const CUMARU_CACHE_DIR = process.env["CUMARU_CACHE_DIR"] ?? "./cumaru";
export const CUMARU_CACHE_FILE =
  process.env["CUMARU_CACHE_FILE"] ?? "cumaru.json";
export const CUMARU_FILE_PREFIX = process.env["CUMARU_FILE_PREFIX"] ?? "cmr";

// keys
export const CUMARU_KEYS_ANTHROPIC_API_KEY =
  process.env["CUMARU_KEYS_ANTHROPIC_API_KEY"] ?? "";
export const CUMARU_KEYS_GEMINI_API_KEY =
  process.env["CUMARU_KEYS_GEMINI_API_KEY"] ?? "";

// llm
export const CUMARU_LLM_CHOICE = process.env["CUMARU_LLM_CHOICE"] ?? "gemini";
export const CUMARU_LLM_MODEL =
  process.env["CUMARU_LLM_MODEL"] ?? CUMARU_LLM_CHOICE === "gemini"
    ? "gemini-2.0-flash"
    : undefined;

// llm
export const CUMARU_LLM_PRE_PROMPT_REPLACE =
  process.env["CUMARU_LLM_PRE_PROMPT_REPLACE"] ?? "";
export const CUMARU_LLM_POST_PROMPT_REPLACE =
  process.env["CUMARU_LLM_POST_PROMPT_REPLACE"] ?? "";

export const CUMARU_LLM_PRE_PROMPT_APPEND =
  process.env["CUMARU_LLM_PRE_PROMPT_APPEND"] ?? "";
export const CUMARU_LLM_POST_PROMPT_APPEND =
  process.env["CUMARU_LLM_POST_PROMPT_APPEND"] ?? "";
