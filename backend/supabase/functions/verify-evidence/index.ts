const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { task, before_image_base64, after_image_base64 } = await request
      .json();
    if (!task || !before_image_base64 || !after_image_base64) {
      return json({ error: "task and both images are required" }, 400);
    }

    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return json({ error: "OPENAI_API_KEY is not configured" }, 500);
    }

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_VISION_MODEL") ?? "gpt-4.1-mini",
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "You verify accountability evidence. Compare only the supplied images. " +
              "Demand substantial completion, but do not infer identity or sensitive traits. " +
              "Return JSON with passed (boolean), confidence (0-1), reason (one factual sentence), " +
              "and roast (one short punchline). The roast must be witty, snarky, specific to a visible " +
              "difference or failure, and funny enough to read on stage. Use playful PG-13 disappointment, " +
              "not generic encouragement, cruelty, slurs, threats, or comments about the person's body.",
          },
          {
            role: "user",
            content: [
              {
                type: "text",
                text: `Task: ${
                  String(task).slice(0, 500)
                }\nCompare BEFORE and AFTER.`,
              },
              {
                type: "image_url",
                image_url: {
                  url: `data:image/jpeg;base64,${before_image_base64}`,
                  detail: "low",
                },
              },
              {
                type: "image_url",
                image_url: {
                  url: `data:image/jpeg;base64,${after_image_base64}`,
                  detail: "low",
                },
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error(
        `OpenAI returned ${response.status}: ${await response.text()}`,
      );
    }

    const completion = await response.json();
    const result = JSON.parse(completion.choices[0].message.content);
    if (
      typeof result.passed !== "boolean" ||
      typeof result.confidence !== "number" ||
      typeof result.reason !== "string"
    ) {
      throw new Error("Model returned an invalid verification payload");
    }

    return json({
      passed: result.passed,
      confidence: Math.max(0, Math.min(1, result.confidence)),
      reason: result.reason.slice(0, 500),
      roast: typeof result.roast === "string"
        ? result.roast.slice(0, 300)
        : null,
    });
  } catch (error) {
    console.error(error);
    return json({
      error: error instanceof Error ? error.message : "Unknown error",
    }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
