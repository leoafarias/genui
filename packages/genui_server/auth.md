# Auth and Discovery

I have a Flutter client application that I'm building that needs to connect to a Genkit deployed server. What is the best way for me to handle discovery of the server URL and authentication?The best way to handle discovery and authentication between a Flutter client and a Genkit server deployed on Google Cloud is to use **environment variables for the server URL** and **Firebase Authentication with OIDC ID tokens for security**.

This approach avoids hardcoding URLs, making it easy to switch between development, staging, and production environments. It also leverages Google Cloud's robust, built-in IAM infrastructure for securing your backend, which is more secure and scalable than managing API keys manually.

## Response

### Server URL Discovery

Your Flutter app needs to know the endpoint of your deployed Genkit flow. Hardcoding this is brittle. The recommended approach is to use environment variables, which can be provided at build time.

The most robust method is using the `--dart-define` flag during your Flutter build. This injects variables that can be accessed as compile-time constants.

1.  **Build/Run with the Variable:** When you run or build your app, pass the Genkit server URL.

    ```bash
    # For a local debug run against a deployed dev server
    flutter run --dart-define=GENKIT_SERVER_URL=https://your-dev-server-url.a.run.app

    # For a production release build
    flutter build apk --dart-define=GENKIT_SERVER_URL=https://your-prod-server-url.a.run.app
    ```

2.  **Access in Dart Code:** You can then access this value in your application code.

    ```dart
    // lib/config.dart
    abstract final class AppConfig {
      static const genkitServerUrl = String.fromEnvironment('GENKIT_SERVER_URL');
    }

    // Usage in your service
    // final url = Uri.parse(AppConfig.genkitServerUrl);
    ```

For local development convenience, you can also use a `.env` file with the `flutter_dotenv` package, but `--dart-define` is the standard for handling different build environments securely.

---

### Authentication

When you deploy your Genkit flow as an HTTP endpoint on Google Cloud (e.g., Cloud Run or Cloud Functions), you should configure it to require authentication. This prevents unauthorized access. The standard way for a mobile client to authenticate is by presenting a signed OIDC ID token from a trusted identity provider, like Firebase Authentication.

The flow is as follows:

1.  **User Sign-In:** The user signs into your Flutter app using a Firebase Authentication method (Google Sign-In, Apple, Email/Password, etc.).
2.  **Token Retrieval:** Upon successful sign-in, your Flutter app requests an OIDC ID token from the Firebase Auth SDK.
3.  **API Request:** Your app makes an HTTPS request to the Genkit endpoint, attaching the ID token in the `Authorization` header as a `Bearer` token.
4.  **Backend Verification:** Google Cloud's infrastructure intercepts the request, validates the token's signature and claims *before* it ever hits your Genkit code, and rejects any unauthorized requests.

---

### Flutter Client Implementation Example

Here is a practical example of a network service class in Flutter that handles adding the auth token to every request automatically using `dio` interceptors.

**1. Add Dependencies:** Add the necessary packages to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.32.0
  firebase_auth: ^4.19.0
  dio: ^5.4.3+1
```

**2. Create a Genkit Service:** This service class encapsulates the logic for communicating with your backend. The `AuthInterceptor` is the key piece—it automatically fetches the current user's ID token and adds it to the request header.

```dart
// lib/services/genkit_service.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Assuming you have a config file like the one described above
import 'package:your_app/config.dart';

class GenkitService {
  late final Dio _dio;

  GenkitService() {
    final options = BaseOptions(
      baseUrl: AppConfig.genkitServerUrl,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    _dio = Dio(options);

    // Add the interceptor to handle auth
    _dio.interceptors.add(AuthInterceptor());
  }

  // Example flow call
  Future<Map<String, dynamic>> getJoke({
    required String topic,
    required int paragraphCount,
  }) async {
    try {
      final response = await _dio.post(
        '/jokeFlow', // The path for your flow
        data: {
          'topic': topic,
          'paragraphCount': paragraphCount,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // Handle errors, e.g., 401/403 for auth failures
      debugPrint('Failed to call jokeFlow: $e');
      rethrow;
    }
  }
}

// This interceptor automatically adds the Firebase Auth ID token
// to the Authorization header of every request.
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // If no user is logged in, you might want to reject the request
      // or allow it to proceed without an auth header for public endpoints.
      debugPrint('No user logged in. Proceeding without auth token.');
      return handler.next(options);
    }

    try {
      final idToken = await user.getIdToken();
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $idToken';
      debugPrint('Added Bearer token to request.');
    } catch (e) {
      debugPrint('Failed to get ID token: $e');
      // Potentially handle token refresh errors here
    }

    return handler.next(options);
  }
}
```

---

### Genkit Server Configuration (Google Cloud Run)

Finally, when you deploy your Genkit flow, you must ensure it requires authentication.

When deploying using the `gcloud` CLI, use the `--no-allow-unauthenticated` flag.

```bash
gcloud run deploy your-genkit-service \
  --source . \
  --region us-central1 \
  --no-allow-unauthenticated
```

This simple flag configures IAM on your Cloud Run service to reject any request that does not include a valid Google-signed OIDC ID token in the `Authorization` header. Your Flutter app, via Firebase Authentication, provides exactly this token, creating a secure and seamless connection.

How would I allow unauthenticated users? Just use --allow-unauthenticated?Yes, that's correct. To allow public access, you would deploy your Cloud Run service with the `--allow-unauthenticated` flag.

```bash
gcloud run deploy your-genkit-service \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

However, this changes the security model significantly. Instead of Cloud Run's infrastructure blocking unauthorized requests, **every request will now reach your Genkit code**. Your application logic becomes responsible for differentiating between anonymous and authenticated users.

---

### Implementing Optional Authentication

This pattern is useful for flows that have a public or "guest" mode but offer enhanced functionality for signed-in users (e.g., personalization, access to saved data).

You can achieve this in your flow definition by using the `firebaseAuth()` policy. When a request comes in, this policy will attempt to validate the `Authorization` header.

*   If a **valid token is present**, it will populate the `auth` object in the flow's context.
*   If the **token is missing or invalid**, the flow will still execute, but the `auth` object will be `null`.

Your code can then check for the existence of the `auth` object to alter its behavior.

### Example Genkit Flow

Here’s how you could modify a Genkit flow to support both authenticated and unauthenticated users. Let's imagine a flow that generates a story; if the user is logged in, it incorporates their name into the story.

```ts
import { configureGenkit } from '@genkit-ai/core';
import { defineFlow, startFlowsServer } from '@genkit-ai/flow';
import { firebaseAuth } from '@genkit-ai/firebase/auth';
import { googleAI } from '@genkit-ai/googleai';
import * as z from 'zod';

configureGenkit({
  plugins: [
    googleAI(),
  ],
  logLevel: 'debug',
  enableTracingAndMetrics: true,
});

export const storyFlow = defineFlow(
  {
    name: 'storyFlow',
    inputSchema: z.object({ topic: z.string() }),
    outputSchema: z.string(),
    // Apply the auth policy. It will not reject unauthenticated requests.
    policy: firebaseAuth((auth) => {
      // You could still reject requests here if needed, e.g., for non-paying users
      // For this example, we allow everyone.
    }),
  },
  async (input, { auth }) => {
    let prompt = `Write a short story about ${input.topic}.`;

    // Check if the auth context exists
    if (auth) {
      console.log(`Authenticated user detected: ${auth.uid}`);
      // Use the display name if available, otherwise a generic title.
      const userName = auth.token.name || 'our esteemed user';
      prompt = `Write a short, personalized story for ${userName} about ${input.topic}.`;
    } else {
      console.log('Anonymous user detected.');
    }

    const llmResponse = await generate({
      prompt: prompt,
      model: 'gemini-1.5-flash',
    });

    return llmResponse.text();
  }
);

startFlowsServer();
```

In this setup:

*   **An unauthenticated user** can call the endpoint. The `auth` object will be `null`, and they'll receive a generic story.
*   **An authenticated user** from your Flutter app will include their ID token. The `firebaseAuth` policy will verify it, populate `auth`, and the user will receive a personalized story.
