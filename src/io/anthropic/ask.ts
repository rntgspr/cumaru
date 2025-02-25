import Anthropic from "@anthropic-ai/sdk";

import { anthroipcApiKey, prePrompt, postPrompt } from "../../consts";
import { CUMARU_LLM_MODEL } from "../../config";

export async function askAnthropic(message: string) {
  const anthropic = new Anthropic({
    apiKey: anthroipcApiKey,
    dangerouslyAllowBrowser: true,
  });

  const response = await anthropic.messages.create({
    model: CUMARU_LLM_MODEL as Anthropic.Model,
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: `${prePrompt}\n\n\n###${message}###\n\n\n${[postPrompt]}`,
      },
    ],
  });

  return response;
}
