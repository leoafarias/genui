import { ai, z } from "./genkit";
import { generateUiRequestSchema } from "./schemas";
import { googleAI } from "@genkit-ai/googleai";
import { cacheService, CacheFlowContext } from "./cache";
import { logger } from "./logger";
import { Message, Part } from "@genkit-ai/ai";

const addOrUpdateSurfaceTool = ai.defineTool(
  {
    name: "addOrUpdateSurface",
    description: "Add or update a UI surface.",
    inputSchema: z.object({
      surfaceId: z.string(),
      definition: z.unknown(),
    }),
    outputSchema: z.void(),
  },
  async () => {}
);

const deleteSurfaceTool = ai.defineTool(
  {
    name: "deleteSurface",
    description: "Delete a UI surface.",
    inputSchema: z.object({
      surfaceId: z.string(),
    }),
    outputSchema: z.void(),
  },
  async () => {}
);

export const generateUiFlow = ai.defineFlow(
  {
    name: "generateUi",
    inputSchema: generateUiRequestSchema,
    outputSchema: z.unknown(),
  },
  async (request, streamingCallback) => {
    const resolvedCache =
      (streamingCallback.context as CacheFlowContext)?.cache || cacheService;

    const catalog = await resolvedCache.getSessionCache(request.sessionId);
    if (!catalog) {
      logger.error(`Invalid session ID: ${request.sessionId}`);
      throw new Error("Invalid session ID");
    }
    logger.debug("Successfully retrieved catalog from cache.");

    // Transform conversation to Genkit's format
    const genkitConversation: Message[] = request.conversation.map(
      (message) => {
        const content: Part[] = message.parts
          .map((part): Part | undefined => {
            if (part.type === "text") {
              return { text: part.text };
            }
            if (part.type === "image") {
              if (part.url) {
                const mediaPart: {
                  media: { url: string; contentType?: string };
                } = {
                  media: { url: part.url },
                };
                if (part.mimeType) {
                  mediaPart.media.contentType = part.mimeType;
                }
                return mediaPart;
              }
              if (part.base64 && part.mimeType) {
                const dataUrl = `data:${part.mimeType};base64,${part.base64}`;
                return { media: { url: dataUrl, contentType: part.mimeType } };
              }
            }
            if (part.type === "ui") {
              return {
                toolRequest: {
                  name: "addOrUpdateSurface",
                  input: part.definition,
                },
              };
            }
            return undefined;
          })
          .filter((p): p is Part => p !== undefined);

        return new Message({
          role: message.role,
          content,
        });
      }
    );

    try {
      logger.debug(
        genkitConversation,
        "Starting AI generation for conversation"
      );
      const { stream, response } = ai.generateStream({
        model: googleAI.model("gemini-pro"),
        messages: genkitConversation,
        tools: [addOrUpdateSurfaceTool, deleteSurfaceTool],
      });

      for await (const chunk of stream) {
        logger.debug({ chunk }, "Chunk from AI");
        streamingCallback(chunk);
      }
      return await response;
    } catch (error) {
      logger.error(error, "An error occurred during AI generation");
      throw error;
    }
  }
);
