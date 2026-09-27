const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const personas = [
  {
    name: "Tiger Mom",
    voice:
      "Strict, theatrical, and devastatingly concise. Treats mediocre effort like a personal insult and lands a sharp punchline.",
  },
  {
    name: "Gentle Mom",
    voice:
      "Weaponized kindness in a calm therapist voice. Sounds supportive while delivering the most quietly savage observation.",
  },
  {
    name: "Corporate Mom",
    voice:
      "A ruthless performance manager turning the failure into an HR incident, KPI miss, or mandatory remediation plan.",
  },
  {
    name: "Cool Mom",
    voice:
      "Desperately wants to seem chill and relatable, but still delivers a cutting consequence with chaotic slang.",
  },
  {
    name: "Passive-Aggressive Mom",
    voice:
      "Profoundly disappointed in the politest possible words. Uses guilt, strategic sighs, and weaponized gratitude.",
  },
];

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { task, failure_reason, consequences } = await request.json();
    if (
      !task || !failure_reason || !Array.isArray(consequences) ||
      consequences.length < 2
    ) {
      return json({
        error:
          "task, failure_reason, and at least two consequences are required",
      }, 400);
    }

    const allowed = consequences.slice(0, 8).map((
      choice: Record<string, unknown>,
    ) => ({
      id: String(choice.id),
      title: String(choice.title).slice(0, 150),
      type: String(choice.type).slice(0, 50),
    }));
    const allowedIDs = new Set(
      allowed.map((choice: { id: string }) => choice.id),
    );
    const brickPhoneChoice = allowed.find(
      ({ type }: { type: string }) => type === "grounded",
    );
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
        model: Deno.env.get("OPENAI_TEXT_MODEL") ?? "gpt-4.1-mini",
        temperature: 1,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "You are the AI jury pool in a comedic accountability app. " +
              'Return JSON shaped exactly as {"votes":[{"persona":string,"choice":string,"comment":string}]}. ' +
              "Return one vote for each supplied persona. choice MUST be an exact allowed consequence id. " +
              "Each persona votes independently according to her stated philosophy. Do not coordinate or force diversity; " +
              "unanimity is allowed when independently justified. Evaluate every option and never use exercise as the generic default. " +
              "For this stage demo, Tiger Mom, Gentle Mom, and Corporate Mom should strongly prefer the grounded/brick-phone option " +
              "when it is authorized, and make the phone lockdown sound hilariously inevitable. " +
              "Each comment must be a short, stage-ready roast that references both a specific failure detail and the chosen consequence. " +
              "Use setup-and-punchline economy and sharply distinct persona voices. Be snarky, surprising, and theatrical—never bland. " +
              "Do not be abusive, " +
              "sexual, discriminatory, or threatening.",
          },
          {
            role: "user",
            content: JSON.stringify({
              sanitized_case: {
                task: String(task).slice(0, 500),
                failure_reason: String(failure_reason).slice(0, 500),
              },
              personas,
              allowed_consequences: allowed,
            }),
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
    const parsed = JSON.parse(completion.choices[0].message.content);
    const parsedVotes = Array.isArray(parsed.votes) ? parsed.votes : [];

    const votes = personas.map((persona, index) => {
      const vote = parsedVotes.find(
        (candidate: Record<string, unknown>) =>
          String(candidate.persona).toLowerCase() ===
            persona.name.toLowerCase(),
      );

      let choice = String(vote?.choice ?? "");
      if (!allowedIDs.has(choice)) {
        const titleMatch = allowed.find(({ title }: { title: string }) =>
          title.toLowerCase() === choice.toLowerCase()
        );
        choice = titleMatch?.id ?? allowed[index % allowed.length].id;
      }
      const isCoreMom = index < 3;
      if (isCoreMom && brickPhoneChoice) {
        choice = brickPhoneChoice.id;
      }
      const selectedTitle = allowed.find(({ id }: { id: string }) =>
        id === choice
      )?.title ??
        "the selected consequence";
      const modelComment = String(vote?.comment ?? "").trim();
      const commentMatchesBrick =
        modelComment.toLowerCase().includes("phone") ||
        modelComment.toLowerCase().includes("brick");

      return {
        persona: persona.name,
        choice,
        comment: isCoreMom && brickPhoneChoice && !commentMatchesBrick
          ? brickPhoneComment(persona.name)
          : modelComment
          ? modelComment.slice(0, 300)
          : fallbackComment(persona.name, selectedTitle),
      };
    });

    return json({ votes });
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

function fallbackComment(persona: string, consequence: string) {
  switch (persona) {
    case "Tiger Mom":
      return `That effort missed the target from across the room. ${consequence}.`;
    case "Gentle Mom":
      return `You did your best, sweetheart. Unfortunately, your best has earned ${consequence}.`;
    case "Corporate Mom":
      return `Your deliverables remain clutter-forward. Remediation: ${consequence}.`;
    case "Cool Mom":
      return `No judgment, bestie—just consequences. Today’s vibe is ${consequence}.`;
    default:
      return `I’m not angry, just impressed you made ${consequence} necessary.`;
  }
}

function brickPhoneComment(persona: string) {
  switch (persona) {
    case "Tiger Mom":
      return "Your room failed inspection, so the distraction rectangle is grounded. Brick the phone.";
    case "Gentle Mom":
      return "Your phone deserves a two-hour nap, and your laundry deserves to finally meet a hanger.";
    default:
      return "We are placing your phone on a two-hour performance improvement plan with zero screen-based deliverables.";
  }
}
