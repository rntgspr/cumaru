# Cumaru

Cumaru is a powerful TypeScript/JavaScript tool that leverages Large Language Models (LLMs) to dynamically generate and manage functions based on natural language descriptions.

## Features

- 🤖 **AI-Powered Function Generation**: Create functions using natural language descriptions
- 💾 **Smart Caching System**: Optimize performance with intelligent response caching
- 🔄 **Dynamic Function Creation**: Generate and save functions on-the-fly
- 📝 **Template String Support**: Use template literals for flexible prompt creation
- 🔒 **Type Safety**: Full TypeScript support with type inference
- 🚀 **Multiple LLM Support**: Compatible with various LLM providers (Anthropic, Google AI)

## Installation

```bash
npm install @cumaru/cumaru
```

## Usage

```typescript
import { cumaru } from '@cumaru/cumaru';

// math super-simple example
type SumTwoNumbers = (numA: number, numB: number) => number;
const numA = 1;
const numB = 2;
const sumTwoNumbers = await cumaru<SumTwoNumbers>`
  You are given two numbers ${numA} and ${numB}.
  Sum the two numbers and return the result.
`;
const resultSumTwoNumbers = sumTwoNumbers?.(3, 2);
console.log("resultSumTwoNumbers", resultSumTwoNumbers); // 5

// string merge example, leetcode 75
type MergeWords = (wordA: string, wordB: string) => string;
const wordA = "abracadabra";
const wordB = "emme";
const mergeWords = await cumaru<MergeWords>`
  You are given two strings ${wordA} and ${wordB}.
  Merge the strings by adding letters in alternating order, starting with first parameter.
  If a string is longer than the other, append the additional letters onto the end of the merged string.
`;
const resultMergeWords = mergeWords?.("abc", "pqr");
console.log("resultMergeWords", resultMergeWords); // apbqcr

// dynamic programming example, leetcode 75
const s = "subsequence";
const t = "sub";
const subsequence = await cumaru<(a: string, b: string) => boolean>`
  Given two strings ${s} and ${t}, return true if s is a subsequence of t, or false otherwise.
  A subsequence of a string is a new string that is formed from the original string by deleting some (can be none) of the characters
  without disturbing the relative positions of the remaining characters. (i.e., "ace" is a subsequence of "abcde" while "aec" is not).
`;
const resultSubsequence = subsequence?.("abc", "ahbgdc");
console.log("resultSubsequence", resultSubsequence); // true
```

## How It Works

1. **Prompt Creation**: Takes a template string with values
2. **Cache Check**: Verifies if a similar function already exists
3. **LLM Processing**: If no cache exists, sends the prompt to the LLM
4. **Function Generation**: Creates a new function based on the LLM response
5. **Storage**: Saves the generated function to disk
6. **Caching**: Updates the cache for future use
7. **Execution**: Returns the logical output or function

## Configuration

Create a `.env` file in your project root with the following variables:

```env
# API Keys
CUMARU_KEYS_ANTHROPIC_API_KEY=your_anthropic_api_key
CUMARU_KEYS_GEMINI_API_KEY=your_gemini_api_key

# LLM Configuration
CUMARU_LLM_CHOICE=gemini  # or anthropic
CUMARU_LLM_MODEL=gemini-2.0-flash  # optional, defaults based on choice

# Cache Configuration
CUMARU_CACHE_DIR=./cumaru  # optional, defaults to ./cumaru
CUMARU_CACHE_FILE=cumaru.json  # optional, defaults to cumaru.json
CUMARU_FILE_PREFIX=cmr  # optional, defaults to cmr

# Logging
CUMARU_LOG_LEVEL=debug  # optional, defaults to debug

# Prompt Customization
CUMARU_LLM_PRE_PROMPT_REPLACE=  # optional, replaces the current pre-prompt
CUMARU_LLM_POST_PROMPT_REPLACE=  # optional, replaces the current post-prompt
CUMARU_LLM_PRE_PROMPT_APPEND=  # optional, appends the current pre-prompt
CUMARU_LLM_POST_PROMPT_APPEND=  # optional, appends the current post-prompt
```

## Default Prompts

### Pre-prompt
```
Create a function that follows the parameters below. Respond with only the function.

Build a JSON with the parameters of: "name" as string, "body" as a string and "parameters", as an array of strings, example:

{
  "name": "substractNumbers",
  "body": "return a - b;",
  "parameters": ["a", "b"]
}

This JSON will create a standard paramters for the "new Function()" class locally to parse it as a real function.
```

### Post-prompt
```
Do not output nothing else, no explanations, no video. No console logs or tests are necessary.

Do not use restricted values.

The variables expressed in these prompts are just examples; Only commit to maintaining their type, not their actual value.

Follow best practices for function construction for Typesceript and Javascript, consider strict linter rules.

Keep in mind, the focus is to use this output as a separate TypeScript file/module.

Do not use blocks of code.

Do not use comments.

Do not use triple quotes.

RESPECT THE JSON STRUCTURE.
```

## Development

```bash
# Install dependencies
npm install

# Build the project
npm run build

# Watch mode for development
npm run watch

# Start the development server
npm start
```

## License

MIT

## Author

Renato Gaspar

