# Architecting Production-Ready Genkit Services: A Deep Dive into HTTP Flows, Payload Handling, and Best Practices

## I. Introduction: From 'Undefined' to Understood

Developers working with modern AI frameworks often encounter challenges that, while seemingly simple, point to deeper architectural principles. A common and frustrating experience when building a Firebase Genkit server is successfully running a flow in the Developer UI, only to find that direct HTTP requests from clients like `cURL` result in the flow receiving an `undefined` payload. This is not an error in the developer's logic but a misunderstanding of the specific API contract that Genkit's HTTP servers expect. This behavior is a frequent point of confusion for those bridging the gap between local development and a deployed, client-accessible service.

The objective of this report is to provide a definitive, expert-level guide that not only resolves this immediate payload issue but also establishes a robust foundation for architecting and deploying production-grade Genkit applications. Genkit is an open-source framework designed to help developers build, test, deploy, and monitor sophisticated AI features with familiar, code-centric patterns. By understanding its core conventions, developers can unlock its full potential for creating scalable and reliable AI services.

This analysis will embark on a detailed journey, beginning with the critical payload structure required by Genkit's Express-based servers. From there, it will proceed to a comprehensive, step-by-step implementation of a sample application, "JokeBot," which accepts a JSON payload, interacts with a generative model, and returns a structured JSON response. The report will cover the entire development lifecycle: project scaffolding, dependency management, strongly-typed schema definition with Zod, and local testing using the powerful Genkit Developer UI. Finally, it will explore production-oriented best practices, including securing the API endpoint with authentication, to ensure the created application is not just functional but also secure and scalable.

## II. The Key to Unlocking Your Payload: The `data` Wrapper

The most direct solution to the problem of a Genkit flow receiving an `undefined` payload from an external HTTP client is to correctly structure the JSON body of the request. Genkit's flow servers, when exposed via the `@genkit-ai/express` plugin, do not consume the raw JSON payload directly as the flow's input. Instead, they expect the payload to be nested within a top-level `data` key.

For example, if a flow is designed to accept an object with `topic` and `paragraphs` fields, the incorrect `cURL` payload would be:

```json
{
  "topic": "pirates",
  "paragraphs": 2
}
```

The correct payload structure, which the Genkit server will successfully parse and pass to the flow, is:

```json
{
  "data": {
    "topic": "pirates",
    "paragraphs": 2
  }
}
```

This requirement is a consistent pattern observed across official documentation and community examples. The official guide for deploying a Node.js Genkit application explicitly demonstrates testing an endpoint with the `curl... -d '{"data": {"name": "Genkit"}}'` format. This convention is further reinforced in tutorials and other practical examples, which consistently use the

`{"data":{...}}` wrapper when making `cURL` requests to Genkit endpoints. This establishes the

`data` wrapper as a required, non-optional part of the API contract for generic HTTP clients interacting with Genkit flows.

This design choice is not arbitrary; it is rooted in Genkit's deep integration with the Google Cloud and Firebase ecosystems, particularly Firebase Callable Functions. The protocol for Firebase Callable Functions standardizes the request body to include a `data` field for the client-provided payload. This structure allows the request envelope to carry other essential, framework-managed metadata alongside the primary data without causing key collisions. For instance, when a client uses a Firebase client SDK, authentication tokens (`authToken`) and App Check tokens (`appCheckToken`) are automatically included at the top level of the request body, separate from the `data` object.

By adopting this same convention, the `@genkit-ai/express` plugin ensures a consistent API surface across different deployment targets. A flow defined in Genkit can be deployed as a Firebase Callable Function using `onCallGenkit` or as a standalone service on any platform using `startFlowServer` with minimal to no changes in the client-side interaction logic. Client libraries designed for Genkit, such as the

`genkit/beta/client` library, abstract this detail away by automatically wrapping the `input` into the `{"data": input}` structure before sending the request. This deliberate design choice enhances portability and ecosystem consistency, reframing the

`data` wrapper from a minor inconvenience to a cornerstone of a well-architected, extensible framework.

## III. Building the "JokeBot" Application: A Step-by-Step Implementation

This section provides a complete, hands-on tutorial for building a Genkit application named "JokeBot." This application will expose an HTTP endpoint that accepts a topic and a desired length, generates a joke using a large language model (LLM), and returns the result as a structured JSON object.

### 3.1. Project Scaffolding and Dependencies

A solid project structure is the foundation of any maintainable application. The first step involves setting up the development environment and installing the necessary packages.

#### Prerequisites

Before beginning, ensure the following tools are installed on the local machine:

- Node.js (version 20 or higher is recommended).
- A code editor, such as Visual Studio Code.
- The Genkit Command Line Interface (CLI), which provides essential developer tools including the local UI. It can be installed globally via npm :

  ```bash
  npm install -g genkit-cli
  ```

#### Project Initialization

The following commands will create a new project directory, initialize it as a Node.js project, and set up the basic source code structure :

```bash
# Create and navigate into the project directory
mkdir genkit-jokebot
cd genkit-jokebot

# Initialize a new Node.js project with default settings
npm init -y

# Create a source directory for TypeScript files
mkdir src
```

#### Installing Dependencies

The JokeBot application requires several packages from the Genkit ecosystem and the broader Node.js community. Each package serves a specific purpose:

- **`genkit`**: The core Genkit SDK, providing the fundamental building blocks like `defineFlow`.
- **`@genkit-ai/googleai`**: The plugin for integrating with Google's Gemini family of models via the Google AI Studio API.
- **`@genkit-ai/express`**: The plugin that provides utilities for exposing Genkit flows as REST API endpoints using the Express.js framework.
- **`express`**: The web application framework for Node.js, a peer dependency for `@genkit-ai/express`.
- **`typescript`**, **`tsx`**, **`@types/node`**: Development dependencies required for writing the application in TypeScript. `tsx` is a modern tool for executing TypeScript files directly, simplifying the development workflow.
- **`zod`**: A TypeScript-first schema declaration and validation library. Genkit leverages Zod extensively for defining type-safe input and output schemas for flows and model interactions.

These dependencies can be installed with the following commands:

```bash
# Install production dependencies
npm install genkit @genkit-ai/googleai @genkit-ai/express express

# Install development dependencies
npm install --save-dev typescript tsx @types/node
```

#### `package.json` Configuration

The `package.json` file serves as the manifest for the project. It is crucial to configure the `scripts` section to define commands for building and running the application. The `start` script will execute the compiled JavaScript, while the `build` script will run the TypeScript compiler (`tsc`).

```json
{
  "name": "genkit-jokebot",
  "version": "1.0.0",
  "description": "A Genkit application that generates jokes via an HTTP API.",
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node --watch lib/index.js",
    "genkit:ui": "genkit start -- npm run start"
  },
  "keywords": ["genkit", "ai", "llm"],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "@genkit-ai/express": "^1.17.1",
    "@genkit-ai/googleai": "^1.1.2",
    "express": "^4.19.2",
    "genkit": "^1.1.1",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.14.2",
    "tsx": "^4.11.0",
    "typescript": "^5.4.5"
  }
}
```

#### `tsconfig.json` Configuration

A `tsconfig.json` file is required to configure the TypeScript compiler. The following configuration is a standard setup for a modern Node.js project, specifying the output directory (`lib`), module system, and other essential compiler options.

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./lib",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "**/*.spec.ts"]
}
```

### 3.2. Configuring the Genkit Environment (`src/index.ts`)

With the project structure in place, the next step is to write the application logic in `src/index.ts`. This begins with configuring the Genkit environment and establishing a connection to the chosen AI model provider.

#### API Key Management

Securely managing API keys is a critical aspect of application development. Keys should never be hardcoded directly into the source code. The standard practice is to use environment variables. For this application, the Gemini API key must be set in the shell environment before running the application.

```bash
export GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
```

Replace `YOUR_GEMINI_API_KEY` with the actual key obtained from Google AI Studio.

#### Genkit Initialization

The `src/index.ts` file is the entry point of the application. The first lines of code will import the necessary modules from Genkit and its plugins, then initialize the core `ai` object. This object is the central point of interaction with the Genkit framework. The initialization process involves registering the `googleAI` plugin, which makes the Gemini models available for use.

```ts
// src/index.ts

import { genkit } from 'genkit';
import { googleAI } from '@genkit-ai/googleai';

// Initialize Genkit and configure it to use the Google AI plugin.
// This allows the application to access Gemini models.
export const ai = genkit({
  plugins:,
  logLevel: 'debug', // Set to 'debug' for detailed logs during development.
  enableTracingAndMetrics: true, // Enable OpenTelemetry for observability.
});
```

### 3.3. Engineering the `jokeGeneratorFlow`

A "flow" is a core concept in Genkit, representing an end-to-end piece of AI-powered logic that can be composed of multiple steps. For the JokeBot, a single flow will encapsulate the entire process of receiving a request, generating a joke, and returning it.

#### The Power of Schemas with Zod

One of Genkit's most powerful features is its use of Zod for defining strongly-typed schemas for both inputs and outputs. This provides several key advantages:

1.  **Type Safety:** It ensures that the data flowing into and out of the system conforms to a predefined structure, catching errors at runtime.
2.  **Validation:** Zod schemas come with built-in validation rules (e.g., `min`, `max`), which simplifies input sanitization.
3.  **Structured Output Generation:** When a Zod schema is provided to a model generation call, it acts as a powerful directive, instructing the model to format its response as a structured object that matches the schema. This is a crucial technique for building reliable APIs that return programmatic, predictable JSON.

#### Defining Input and Output Schemas

For the JokeBot, two schemas are needed: one for the incoming request and one for the outgoing response. These are defined using Zod's `object` constructor.

```ts
// src/index.ts (continued)

import { z } from "genkit";

// Define the schema for the incoming request payload.
// This ensures that any data passed to the flow has a 'topic' (string)
// and 'paragraphs' (a number between 1 and 5).
export const JokeRequestSchema = z.object({
  topic: z.string().describe("The subject for the joke"),
  paragraphs: z
    .number()
    .min(1)
    .max(5)
    .describe("The desired number of paragraphs for the joke"),
});

// Define the schema for the final JSON response.
// This ensures the model's output is structured with a 'title' and a 'joke'.
export const JokeResponseSchema = z.object({
  title: z.string().describe("A creative title for the joke"),
  joke: z.string().describe("The generated joke text"),
});
```

By passing `JokeResponseSchema` to the `ai.generate` call, the application is not merely hoping for valid JSON; it is leveraging the model's underlying function-calling or tool-use capabilities. The framework instructs the model to generate its response in the specified structure, which Genkit then parses and validates. This technique is fundamental to building reliable AI-powered services and represents a significant advantage over making raw, unstructured API calls to a model.

#### Defining the Flow

With the schemas defined, the flow itself can be created using `ai.defineFlow`. This function takes a configuration object (including the `name` and schemas) and an asynchronous function that contains the flow's logic.

```ts
// src/index.ts (continued)

import { googleAI } from "@genkit-ai/googleai";

// Define the main application logic as a Genkit flow.
export const jokeGeneratorFlow = ai.defineFlow(
  {
    name: "jokeGeneratorFlow",
    inputSchema: JokeRequestSchema,
    outputSchema: JokeResponseSchema,
  },
  async (input) => {
    // Dynamically construct a prompt for the LLM using the validated input.
    const prompt = `Generate a creative, funny joke about the topic: "${input.topic}".
    The joke should be exactly ${input.paragraphs} paragraph(s) long.
    Provide a short, catchy title for the joke.`;

    // Call the generative model.
    const { output } = await ai.generate({
      model: googleAI.model("gemini-1.5-flash"), // Specify the model to use.
      prompt: prompt,
      output: {
        schema: JokeResponseSchema, // Instruct the model to generate a structured response.
      },
    });

    // Handle cases where the model fails to generate valid, structured output.
    if (!output) {
      throw new Error("Failed to generate a joke that satisfies the schema.");
    }

    // Return the structured output. Genkit ensures it matches JokeResponseSchema.
    return output;
  }
);
```

### 3.4. Exposing the Flow as a REST API

The final step in `src/index.ts` is to expose the `jokeGeneratorFlow` as an HTTP endpoint. The `@genkit-ai/express` plugin provides a convenient helper function, `startFlowServer`, for this exact purpose. It creates a lightweight Express server and automatically maps each provided flow to an endpoint named after the flow.

```ts
// src/index.ts (continued)

import { startFlowServer } from "@genkit-ai/express";

// Start a simple Express server to expose the defined flows.
startFlowServer({
  flows: [jokeGeneratorFlow], // An array of flows to expose as API endpoints.
  port: 3400, // The network port to listen on.
  cors: "*", // Configure CORS policy. '*' is suitable for development.
});
```

The `cors: '*'` setting allows requests from any origin, which is convenient for local development. In a production environment, this should be replaced with a more restrictive policy, such as a list of allowed domains. With this code, the server will start on port 3400 and create a POST endpoint at `http://localhost:3400/jokeGeneratorFlow`.

## IV. Execution and Verification: Bringing JokeBot to Life

With the code complete, it is time to build, run, and test the application. Genkit provides powerful tools that facilitate both interactive debugging and end-to-end testing.

### 4.1. Local Development with the Genkit UI

The Genkit Developer UI is an indispensable tool for local development. It provides a web-based interface for running flows, inspecting execution traces, and debugging AI logic in real-time.

#### Launching the Application and UI

First, build the TypeScript project into JavaScript:

```bash
npm run build
```

Next, launch the application and the Developer UI simultaneously using the script defined in `package.json`:

```bash
npm run genkit:ui
```

Alternatively, one can use the more direct command:

```bash
genkit start -- npm run start
```

This command accomplishes two things: it starts the Genkit tools server, which serves the Developer UI on port 4000, and it starts the JokeBot application process (`npm run start`), watching for file changes. The Genkit server attaches to the application process to discover its defined flows and other components.

#### Using the UI for Testing

Navigate to `http://localhost:4000` in a web browser. The UI will display a list of all discovered flows.

1.  Select `jokeGeneratorFlow` from the list.
2.  The UI will present a structured input form based on the `JokeRequestSchema`. Enter a topic (e.g., "coffee") and a number of paragraphs (e.g., 1).
3.  Click the "Run" button.

The flow will execute, and the UI will display the structured JSON output. Crucially, it also provides an "Inspect" view, which shows a detailed trace of the flow's execution. This trace includes the exact prompt sent to the LLM, the raw response from the model, and the timing of each step, making it an invaluable resource for debugging and performance tuning.

### 4.2. End-to-End Testing with `cURL`

While the Developer UI is excellent for interactive testing, `cURL` is the standard tool for verifying that the HTTP endpoint behaves as expected for external clients.

#### The `test.sh` Script

Create a file named `test.sh` to encapsulate the `cURL` command. This makes testing repeatable and easy to share.

```bash
#!/bin/bash
# This script sends a POST request to the JokeBot's HTTP endpoint.

# Use -s for silent mode to suppress progress meter.
# Use | jq for pretty-printing the JSON response (optional, requires jq to be installed).
curl -s -X POST "http://127.0.0.1:3400/jokeGeneratorFlow" \
-H "Content-Type: application/json" \
-d '{
  "data": {
    "topic": "software developers",
    "paragraphs": 2
  }
}' | jq
```

Make the script executable:

```bash
chmod +x test.sh
```

#### Deconstructing the Command

To run the test, execute the script from the terminal while the JokeBot server is running:

```bash
./test.sh
```

Each part of the `cURL` command is critical:

- `-X POST`: Specifies the HTTP POST method, as the server is configured to listen for POST requests.
- `"http://127.0.0.1:3400/jokeGeneratorFlow"`: The full URL of the endpoint. The path `/jokeGeneratorFlow` is derived directly from the flow's `name` property.
- `-H "Content-Type: application/json"`: This header informs the server that the request body contains JSON data, allowing the Express `json()` middleware (used internally by `startFlowServer`) to parse it correctly.
- `-d '{"data": {...}}'`: The request body. This demonstrates the crucial `data` wrapper. The entire JSON object that matches the `JokeRequestSchema` is placed inside the `"data"` key.

A successful execution will print a well-formatted JSON object to the console, containing a `title` and a `joke`, confirming that the entire system—from HTTP request to model generation to structured response—is working correctly.

## V. Advancing to Production: Security and Scalability

A functional prototype is an excellent start, but deploying an application to production requires additional considerations, primarily around security and architectural flexibility.

### 5.1. Securing Your API Endpoint

Exposing an unauthenticated API that consumes resources from a metered service like a generative model is a significant security risk. It is essential to implement an authentication mechanism to control access. A common and straightforward approach for service-to-service communication is to use a static API key.

#### Implementing API Key Authentication

Genkit provides a clean, declarative pattern for adding authentication using "context providers." The `apiKey` provider from `genkit/context` can be used to protect a flow, requiring clients to present a valid bearer token in the `Authorization` header.

The `src/index.ts` file can be modified as follows:

```ts
// src/index.ts (modified for authentication)

//... (imports for genkit, googleAI, z, schemas, and flow definition remain the same)

import { startFlowServer, withContextProvider } from '@genkit-ai/express';
import { apiKey } from 'genkit/context';

// This is a new environment variable for the API key.
const JOKEBOT_API_KEY = process.env.JOKEBOT_API_KEY;

if (!JOKEBOT_API_KEY) {
  throw new Error('JOKEBOT_API_KEY environment variable is not set.');
}

startFlowServer({
  flows:,
  port: 3400,
  cors: '*',
});
```

The `withContextProvider` function is Genkit's declarative method for applying middleware to a flow. The `apiKey` provider is a pre-built middleware that handles the logic of extracting a bearer token from the `Authorization` header and validating it against the provided key. This approach keeps the core flow logic clean and separate from authentication concerns.

#### Updating the Test Script

To test the secured endpoint, the `test.sh` script must be updated to include the `Authorization` header. First, set the new environment variable:

```bash
export JOKEBOT_API_KEY="my-super-secret-key"
```

Then, modify `test.sh`:

```bash
#!/bin/bash
# This script tests the SECURED JokeBot endpoint.

API_KEY="my-super-secret-key"

curl -s -X POST "http://127.0.0.1:3400/jokeGeneratorFlow" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer ${API_KEY}" \
-d '{
  "data": {
    "topic": "cybersecurity",
    "paragraphs": 1
  }
}' | jq
```

Running this script will now succeed, while any request without the correct bearer token will be rejected with a `401 Unauthorized` error.

### 5.2. A Comparison of Server Strategies

The `startFlowServer` function is excellent for simple, dedicated microservices. However, for applications with more complex routing, custom middleware, or integration into an existing Express.js project, Genkit provides the `expressHandler` function. This function offers greater flexibility and control over the server implementation.

An example of using `expressHandler` in a custom server:

```ts
// Example of a custom Express server with Genkit
import express from "express";
import { expressHandler } from "@genkit-ai/express";
import { jokeGeneratorFlow } from "./flows"; // Assuming flow is in a separate file

const app = express();

// This middleware is crucial for parsing JSON request bodies.
app.use(express.json());

// Custom logging middleware
app.use((req, res, next) => {
  console.log(`Request received for: ${req.path}`);
  next();
});

// Map the Genkit flow to a custom route.
app.post("/api/v1/generate-joke", expressHandler(jokeGeneratorFlow));

app.listen(3400, () => {
  console.log("Custom JokeBot server listening on port 3400");
});
```

The choice between `startFlowServer` and `expressHandler` depends on the application's architectural needs. The following table provides a clear comparison to guide this decision.

| Feature              | `startFlowServer`                                                                                                                                          | `expressHandler`                                                                                                                                       |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Primary Use Case** | Quickly exposing one or more flows as a standalone microservice. Ideal for rapid prototyping and simple APIs.                                              | Integrating Genkit flows as specific routes within a larger, custom Express.js application with other endpoints.                                       |
| **Configuration**    | Via a single configuration object passed to the function (port, CORS, prefix, authentication context). Follows a "convention over configuration" approach. | As Express middleware, allowing for route-specific configurations and the use of custom preceding middleware (e.g., logging, advanced auth).           |
| **Flexibility**      | Lower. Follows Genkit conventions, such as the endpoint path being derived from the flow's name.                                                           | Higher. Provides full control over routing (e.g., `/api/v2/joke`), the request/response lifecycle, and integration with the broader Express ecosystem. |
| **Relevant Sources** |                                                                                                                                                            |                                                                                                                                                        |

### 5.3. Pathways to Deployment

The self-contained Node.js server created in this report is well-suited for deployment on various modern cloud platforms. Because it is a standard Express application, it can be containerized using Docker and deployed to any service that supports containers.

- **Google Cloud Run:** A fully managed, serverless platform ideal for containerized applications. It automatically scales based on traffic, including scaling down to zero, making it highly cost-effective.
- **Cloud Functions for Firebase:** For applications tightly integrated with the Firebase ecosystem, flows can be wrapped with `onCallGenkit` and deployed as individual functions, leveraging built-in triggers and authentication with Firebase services.

In both cases, API keys and other secrets should be managed using a dedicated secret management service, such as Google Cloud Secret Manager, to ensure they are not exposed in the deployment environment.

## VI. Conclusion: Your Foundation for Building with Genkit

This report has systematically deconstructed and solved a common challenge in developing Genkit applications, transforming an initial point of friction into a deep understanding of the framework's design and capabilities. The journey from an `undefined` payload to a secure, production-ready API endpoint has illuminated several core principles that are essential for any developer working with Genkit.

The most critical takeaways include:

- **The `data` Wrapper Convention:** The requirement for nesting HTTP payloads within a `data` key is a deliberate design choice for consistency with the Firebase ecosystem, enabling a unified API surface for metadata and user data.
- **The Power of Zod Schemas:** Schemas are not merely for validation; they are a powerful tool for directing LLMs to produce reliable, structured JSON output, which is fundamental to building programmatic AI services.
- **The Utility of the Developer UI:** The Genkit Developer UI is an essential tool for rapid iteration, providing unparalleled visibility into flow execution traces, which drastically simplifies debugging and prompt engineering.
- **A Layered Approach to Production:** Moving from prototype to production involves layering on concerns like security. Genkit's context providers offer a clean, declarative middleware pattern for implementing authentication without cluttering business logic.

The knowledge and the "JokeBot" application built here serve as a robust foundation. With this understanding, developers are now well-equipped to explore more advanced Genkit features, such as building complex multi-step flows, implementing Retrieval-Augmented Generation (RAG) for context-aware responses , defining custom tools for agentic workflows , and constructing sophisticated AI agents. Genkit provides the tools to move beyond simple generative calls and into the realm of creating truly intelligent, integrated, and observable AI-powered applications.

## VII. Appendix: Complete Project Source Code

For ease of reference and use, this section contains the complete, final source code for the "JokeBot" application, including the secure version with API key authentication.

### `package.json`

```json
{
  "name": "genkit-jokebot",
  "version": "1.0.0",
  "description": "A Genkit application that generates jokes via an HTTP API.",
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node --watch lib/index.js",
    "genkit:ui": "genkit start -- npm run start"
  },
  "keywords": ["genkit", "ai", "llm"],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "@genkit-ai/express": "^1.17.1",
    "@genkit-ai/googleai": "^1.1.2",
    "express": "^4.19.2",
    "genkit": "^1.1.1",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.14.2",
    "tsx": "^4.11.0",
    "typescript": "^5.4.5"
  }
}
```

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./lib",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "**/*.spec.ts"]
}
```

### `src/index.ts` (with API Key Authentication)

```ts
import { genkit, z } from 'genkit';
import { googleAI } from '@genkit-ai/googleai';
import { startFlowServer, withContextProvider } from '@genkit-ai/express';
import { apiKey } from 'genkit/context';

// Initialize Genkit and configure it to use the Google AI plugin.
export const ai = genkit({
  plugins: [googleAI()],
  logLevel: 'debug',
  enableTracingAndMetrics: true,
});

// Define the schema for the incoming request payload.
export const JokeRequestSchema = z.object({
  topic: z.string().describe('The subject for the joke'),
  paragraphs: z
   .number()
   .min(1)
   .max(5)
   .describe('The desired number of paragraphs for the joke'),
});

// Define the schema for the final JSON response.
export const JokeResponseSchema = z.object({
  title: z.string().describe('A creative title for the joke'),
  joke: z.string().describe('The generated joke text'),
});

// Define the main application logic as a Genkit flow.
export const jokeGeneratorFlow = ai.defineFlow(
  {
    name: 'jokeGeneratorFlow',
    inputSchema: JokeRequestSchema,
    outputSchema: JokeResponseSchema,
  },
  async (input) => {
    const prompt = `Generate a creative, funny joke about the topic: "${input.topic}".
    The joke should be exactly ${input.paragraphs} paragraph(s) long.
    Provide a short, catchy title for the joke.`;

    const { output } = await ai.generate({
      model: googleAI.model('gemini-1.5-flash'),
      prompt: prompt,
      output: {
        schema: JokeResponseSchema,
      },
    });

    if (!output) {
      throw new Error('Failed to generate a joke that satisfies the schema.');
    }

    return output;
  }
);

// Retrieve the required API key from environment variables for security.
const JOKEBOT_API_KEY = process.env.JOKEBOT_API_KEY;

if (!JOKEBOT_API_KEY) {
  console.error('FATAL: JOKEBOT_API_KEY environment variable is not set.');
  process.exit(1);
}

// Start a simple Express server to expose the defined flows.
startFlowServer({
  flows:,
  port: 3400,
  cors: '*', // For production, restrict this to your app's domain.
});
```

### `test.sh` (for Secured Endpoint)

```bash
#!/bin/bash
# This script sends an authenticated POST request to the JokeBot's HTTP endpoint.

# Ensure the JOKEBOT_API_KEY is set in your environment or defined here.
# For example: export JOKEBOT_API_KEY="my-super-secret-key"
if]; then
  echo "Error: JOKEBOT_API_KEY environment variable is not set."
  exit 1
fi

echo "Testing JokeBot with topic: 'artificial intelligence'..."

# Use -s for silent mode to suppress progress meter.
# Use | jq for pretty-printing the JSON response (optional).
curl -s -X POST "http://127.0.0.1:3400/jokeGeneratorFlow" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer ${JOKEBOT_API_KEY}" \
-d '{
  "data": {
    "topic": "artificial intelligence",
    "paragraphs": 1
  }
}' | jq
```

[![image](https://t1.gstatic.com/faviconV2?url=https://github.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

github.com

[firebase/genkit: An open source framework for building AI-powered apps with familiar code-centric patterns. Genkit makes it easy to develop, integrate, and test AI features with observability and evaluations. Genkit works with various models and platforms. - GitHub Opens in a new window](https://github.com/firebase/genkit)[![image](https://t1.gstatic.com/faviconV2?url=https://developers.googleblog.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

developers.googleblog.com

[How Firebase Genkit helped add AI to our Compass app - Google Developers Blog Opens in a new window](https://developers.googleblog.com/en/how-firebase-genkit-helped-add-ai-to-our-compass-app/)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Deploy flows to any Node.js platform - JS - Genkit - Firebase - Google Opens in a new window](https://firebase.google.com/docs/genkit/deploy-node)[![image](https://t3.gstatic.com/faviconV2?url=https://courses.xavidop.me/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

courses.xavidop.me

[Introductory workshop to Firebase GenKit - Codelabs Opens in a new window](https://courses.xavidop.me/posts/genkit-workshop/)[![image](https://t0.gstatic.com/faviconV2?url=https://medium.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

medium.com

[Deploying Your Firebase Genkit Application with Firebase Functions | by Yuki Nagae Opens in a new window](https://medium.com/@yukinagae/deploying-your-firebase-genkit-application-with-firebase-functions-99c7d0044964)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Invoke Genkit flows from your App | Cloud Functions for Firebase - Google Opens in a new window](https://firebase.google.com/docs/functions/oncallgenkit)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Authorization and integrity - JS - Genkit - Firebase - Google Opens in a new window](https://firebase.google.com/docs/genkit/auth)[![image](https://t0.gstatic.com/faviconV2?url=https://www.npmjs.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

npmjs.com

[genkit-ai/express - NPM Opens in a new window](https://www.npmjs.com/package/@genkit-ai/express)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Get started with Genkit JS - Firebase Opens in a new window](https://firebase.google.com/docs/genkit/get-started)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Genkit Developer Tools - JS - Firebase - Google Opens in a new window](https://firebase.google.com/docs/genkit/devtools)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Defining AI workflows - JS - Genkit - Firebase - Google Opens in a new window](https://firebase.google.com/docs/genkit/flows)[![image](https://t3.gstatic.com/faviconV2?url=https://www.cloudskillsboost.google/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

cloudskillsboost.google

[Firebase Genkit Components - Structured Data for Prompts and Flows | Google Cloud Skills Boost Opens in a new window](https://www.cloudskillsboost.google/course_templates/1189/video/528757?locale=id)[![image](https://t2.gstatic.com/faviconV2?url=https://firebase.google.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.google.com

[Generating content with AI models - JS - Genkit - Firebase - Google Opens in a new window](https://firebase.google.com/docs/genkit/models)[![image](https://t0.gstatic.com/faviconV2?url=https://dev.to/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

dev.to

[Firebase Genkit-AI: Level Up Your Skills with AI-Powered Flows - DEV Community Opens in a new window](https://dev.to/this-is-learning/firebase-genkit-ai-level-up-your-skills-with-ai-powered-flows-3foj)[![image](https://t3.gstatic.com/faviconV2?url=https://firebase.blog/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

firebase.blog

[Announcing Firebase Genkit 1.0 for Node.js Opens in a new window](https://firebase.blog/posts/2025/02/announcing-genkit/)[![image](https://t0.gstatic.com/faviconV2?url=https://www.youtube.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

youtube.com

[Firebase After Hours #3 - Genkit: More than Meets the AI! - YouTube Opens in a new window](https://www.youtube.com/watch?v=VFPsp7aURWA)[![image](https://t0.gstatic.com/faviconV2?url=https://www.youtube.com/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

youtube.com

[Build AI agents with Cloud Run and Firebase Genkit - YouTube Opens in a new window](https://www.youtube.com/watch?v=CfmG32Jvme8&vl=en)[![image](https://t3.gstatic.com/faviconV2?url=https://www.cloudskillsboost.google/&client=BARD&type=FAVICON&size=256&fallback_opts=TYPE,SIZE,URL)

cloudskillsboost.google

[Build Generative AI Apps with Firebase Genkit | Google Cloud Skills Boost](https://www.cloudskillsboost.google/course_templates/1189)
