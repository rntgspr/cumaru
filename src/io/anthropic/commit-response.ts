import { Anthropic } from "@anthropic-ai/sdk";

export function commitResponseAnthropic(
  response: Anthropic.Messages.Message
): string {
  const result = response.content.reduce((acc: string, item: any) => {
    const nextAcc = acc + (item.type === "text" ? item.text : "");
    return nextAcc;
  }, "");

  return result;
}
