import { v4 as uuidv4 } from 'uuid';
import { ai, z } from './genkit';
import { startSessionRequestSchema } from './schemas';
import { setSessionCache } from './cache';
import { logger } from './logger';

export const startSessionFlow = ai.defineFlow(
  {
    name: 'startSession',
    inputSchema: startSessionRequestSchema,
    outputSchema: z.string(),
  },
  async (request) => {
    logger.info('Starting new session...');
    const sessionId = uuidv4();
    logger.debug(`Generated session ID: ${sessionId}`);
    await setSessionCache(sessionId, request.catalog);
    logger.info(`Successfully started session ${sessionId}`);
    return sessionId;
  }
);
