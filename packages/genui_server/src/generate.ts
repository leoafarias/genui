// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import { ai, z } from './genkit';
import { generateUiRequestSchema } from './schemas';
import { googleAI } from '@genkit-ai/googleai';
import { getSessionCache } from './cache';
import { logger } from './logger';

const addOrUpdateSurfaceTool = ai.defineTool(
  {
    name: 'addOrUpdateSurface',
    description: 'Add or update a UI surface.',
    inputSchema: z.object({
      surfaceId: z.string(),
      definition: z.any(),
    }),
    outputSchema: z.void(),
  },
  async (input) => {}
);

const deleteSurfaceTool = ai.defineTool(
  {
    name: 'deleteSurface',
    description: 'Delete a UI surface.',
    inputSchema: z.object({
      surfaceId: z.string(),
    }),
    outputSchema: z.void(),
  },
  async (input) => {}
);

export const generateUiFlow = ai.defineFlow(
  {
    name: 'generateUi',
    inputSchema: generateUiRequestSchema,
    outputSchema: z.any(),
    stream: true,
  },
  async (request, streamingCallback) => {
    logger.info(`Generating UI for session ID: ${request.sessionId}`);
    const catalog = await getSessionCache(request.sessionId);
    if (!catalog) {
      logger.error(`Invalid session ID: ${request.sessionId}`);
      throw new Error('Invalid session ID');
    }
    logger.debug('Successfully retrieved catalog from cache.');

    try {
      logger.debug(
        request.conversation,
        'Starting AI generation for conversation'
      );
      const { stream, response } = ai.generateStream({
        model: googleAI.model('gemini-pro'),
        prompt: request.conversation as any,
        tools: [addOrUpdateSurfaceTool, deleteSurfaceTool],
      });

      for await (const chunk of stream) {
        logger.debug({ chunk }, 'Chunk from AI');
        if (chunk.toolRequests) {
          logger.info('Yielding tool request from AI.');
          streamingCallback({
            type: 'toolRequest',
            toolRequests: chunk.toolRequests,
          });
        }
      }
      return await response;
    } catch (error) {
      logger.error(error, 'An error occurred during AI generation');
      throw error;
    }
  }
);
