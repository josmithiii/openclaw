import { describe, expect, it } from "vitest";
import { sanitizeGoogleThinkingPayload } from "./google-stream-wrappers.js";

describe("sanitizeGoogleThinkingPayload", () => {
  it("removes thinkingBudget=0 for gemini-2.5-pro (thinking-required model)", () => {
    const payload = {
      config: {
        thinkingConfig: { thinkingBudget: 0 },
      },
    };
    sanitizeGoogleThinkingPayload({ payload, modelId: "gemini-2.5-pro" });
    expect(payload.config.thinkingConfig).not.toHaveProperty("thinkingBudget");
  });

  it("removes thinkingBudget=0 for gemini-2.5-pro with provider prefix", () => {
    const payload = {
      config: {
        thinkingConfig: { thinkingBudget: 0 },
      },
    };
    sanitizeGoogleThinkingPayload({ payload, modelId: "google/gemini-2.5-pro-preview" });
    expect(payload.config.thinkingConfig).not.toHaveProperty("thinkingBudget");
  });

  it("keeps thinkingBudget=0 for non-thinking-required models like gemini-2.5-flash", () => {
    const payload = {
      config: {
        thinkingConfig: { thinkingBudget: 0 },
      },
    };
    sanitizeGoogleThinkingPayload({ payload, modelId: "gemini-2.5-flash" });
    expect(payload.config.thinkingConfig).toHaveProperty("thinkingBudget", 0);
  });

  it("keeps positive thinkingBudget for gemini-2.5-pro", () => {
    const payload = {
      config: {
        thinkingConfig: { thinkingBudget: 1000 },
      },
    };
    sanitizeGoogleThinkingPayload({ payload, modelId: "gemini-2.5-pro" });
    expect(payload.config.thinkingConfig).toHaveProperty("thinkingBudget", 1000);
  });

  it("removes negative thinkingBudget for any model", () => {
    const payload = {
      config: {
        thinkingConfig: { thinkingBudget: -1 },
      },
    };
    sanitizeGoogleThinkingPayload({ payload, modelId: "gemini-3.1-pro" });
    expect(payload.config.thinkingConfig).not.toHaveProperty("thinkingBudget");
  });

  it("sets thinkingLevel for gemini-3.1 models when thinking is enabled and budget was negative", () => {
    const payload = {
      config: {
        thinkingConfig: { thinkingBudget: -1 },
      },
    };
    sanitizeGoogleThinkingPayload({ payload, modelId: "gemini-3.1-pro", thinkingLevel: "high" });
    expect(payload.config.thinkingConfig).toEqual({ thinkingLevel: "HIGH" });
  });

  it("is a no-op when payload has no thinkingConfig", () => {
    const payload = { config: {} };
    sanitizeGoogleThinkingPayload({ payload, modelId: "gemini-2.5-pro" });
    expect(payload.config).toEqual({});
  });
});
