import { genkit, z } from "genkit";
import { googleAI } from "@genkit-ai/googleai";
import { googleCloud } from "@genkit-ai/google-cloud";

export { z };

export const ai = genkit({
  plugins: [googleAI(), googleCloud()],
  model: "googleai/gemini-1.5-flash",
});
