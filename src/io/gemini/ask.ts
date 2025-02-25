import { GoogleGenerativeAI, GenerativeModel } from "@google/generative-ai";

import { geminiApiKey, prePrompt, postPrompt } from "../../consts";
import { CUMARU_LLM_MODEL } from "../../config";

export async function askGemini(message: string) {
  const generativeAIClient = new GoogleGenerativeAI(geminiApiKey);
  const model = generativeAIClient.getGenerativeModel({
    model: CUMARU_LLM_MODEL as string,
  });

  const response = await model.generateContent([
    `${prePrompt}\n\n\n###${message}###\n\n\n${postPrompt}`,
  ]);

  return response;
}
