import { GenerateContentResult } from "@google/generative-ai";

export function commitResponseGemini(response: GenerateContentResult): string {
  const result = response.response.text();

  // .reduce((acc: string, item: any) => {
  //   const nextAcc = acc + (item.type === "text" ? item.text : "");
  //   return nextAcc;
  // }, "");

  return result;
}
