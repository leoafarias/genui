// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import { getFirestore } from '@genkit-ai/google-cloud';
import { logger } from './logger';

const db = getFirestore();
const sessionCollection = db.collection('sessions');

/**
 * Stores the catalog for a given session ID in Firestore.
 * @param sessionId The unique identifier for the session.
 * @param catalog The widget catalog to store.
 */
export async function setSessionCache(
  sessionId: string,
  catalog: any
): Promise<void> {
  logger.debug(`Storing catalog in Firestore for session ID: ${sessionId}`);
  await sessionCollection.doc(sessionId).set({ catalog });
}

/**
 * Retrieves the catalog for a given session ID from Firestore.
 * @param sessionId The unique identifier for the session.
 * @returns The catalog, or null if the session is not found.
 */
export async function getSessionCache(sessionId: string): Promise<any | null> {
  logger.debug(`Retrieving catalog from Firestore for session ID: ${sessionId}`);
  const doc = await sessionCollection.doc(sessionId).get();
  if (!doc.exists) {
    logger.warn(`No session document found for ID: ${sessionId}`);
    return null;
  }
  return doc.data()?.catalog;
}
