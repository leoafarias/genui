import { generateUiFlow } from "../generate";
import { GenerateUiRequest } from "../schemas";

describe("generateUiFlow", () => {
  it("should throw an error if no catalog is provided", async () => {
    await expect(async () => {
      const result = generateUiFlow.stream(
        {
          catalog: null,
          conversation: [],
        } as unknown as GenerateUiRequest,
        {}
      );
      for await (const _chunk of result.stream) {
        // This should not be reached.
      }
    }).rejects.toThrow("Expected object, received null");
  });
});
