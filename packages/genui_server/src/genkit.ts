import { genkit, z } from "genkit";
import { googleAI } from "@genkit-ai/googleai";

export { z };

export const ai = genkit({
  plugins: [googleAI()],
  model: "googleai/gemini-1.5-flash",
});
