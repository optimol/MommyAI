import { createClient } from "@supabase/supabase-js";
import "./style.css";

const app = document.querySelector("#app");
const requestedCaseID = new URLSearchParams(window.location.search).get("case");
const supabaseURL = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

if (!supabaseURL || !supabaseKey) {
  renderError("Court is not configured", "Copy .env.example to .env and add the Supabase public values.");
} else {
  const supabase = createClient(supabaseURL, supabaseKey);
  if (requestedCaseID) {
    startCourt(supabase, requestedCaseID);
  } else {
    waitForCourt(supabase);
  }
}

async function waitForCourt(supabase) {
  renderLobby();
  let hasStarted = false;

  const openCase = async (caseID) => {
    if (hasStarted) return;
    hasStarted = true;
    await supabase.removeChannel(channel);
    const url = new URL(window.location.href);
    url.searchParams.set("case", caseID);
    window.history.replaceState({}, "", url);
    startCourt(supabase, caseID);
  };

  const findOpenCase = async () => {
    const { data, error } = await supabase
      .from("cases")
      .select("id")
      .eq("status", "open")
      .gt("closes_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      renderError("Court lobby unavailable", error.message);
      return;
    }
    if (data) openCase(data.id);
  };

  const channel = supabase
    .channel("court-lobby")
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "cases" },
      ({ new: courtCase }) => {
        if (courtCase.status === "open") openCase(courtCase.id);
      },
    )
    .subscribe((status) => {
      if (status === "SUBSCRIBED") findOpenCase();
    });
}

async function startCourt(supabase, caseID) {
  const voterID = getVoterID();

  const [caseResult, consequenceResult, voteResult] = await Promise.all([
    supabase.from("cases").select("*").eq("id", caseID).single(),
    fetchConsequences(supabase, caseID),
    supabase.from("votes").select("*").eq("case_id", caseID).eq("voter_id", voterID).maybeSingle(),
  ]);

  if (caseResult.error || consequenceResult.error) {
    renderError(
      "Court could not convene",
      caseResult.error?.message ?? consequenceResult.error?.message ?? "Unknown error",
    );
    return;
  }

  const courtCase = caseResult.data;
  const consequences = consequenceResult.data;
  let existingVote = voteResult.data;
  let secondsLeft = remainingSeconds(courtCase.closes_at);
  let submitting = false;

  render();

  const timer = window.setInterval(() => {
    secondsLeft = remainingSeconds(courtCase.closes_at);
    updateCountdown(secondsLeft);
    if (secondsLeft <= 0) {
      window.clearInterval(timer);
      render();
    }
  }, 250);

  const channel = supabase
    .channel(`jury-${caseID}`)
    .on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "cases", filter: `id=eq.${caseID}` },
      ({ new: updatedCase }) => {
        Object.assign(courtCase, updatedCase);
        render();
      },
    )
    .subscribe();

  window.addEventListener("beforeunload", () => {
    window.clearInterval(timer);
    supabase.removeChannel(channel);
  });

  function render() {
    const isClosed = courtCase.status === "closed" || secondsLeft <= 0;
    const selected = existingVote?.consequence_id;

    app.innerHTML = `
      <section class="court">
        <header>
          <div class="live"><span></span>${isClosed ? "VOTING CLOSED" : "LIVE COURT"}</div>
          <div class="gavel">⚖️</div>
          <p class="eyebrow">MOMMY COURT</p>
          <h1>An irresponsible child has failed.</h1>
        </header>

        <article class="case-file">
          <span>THE BROKEN PROMISE</span>
          <h2>“${escapeHTML(courtCase.task_description)}”</h2>
          <p>${escapeHTML(courtCase.failure_reason)}</p>
        </article>

        ${
          existingVote
            ? `
              <section class="receipt">
                <div>✓</div>
                <h2>YOUR VOTE IS IN</h2>
                <p>Mommy appreciates your service.</p>
              </section>
            `
            : isClosed
              ? `
                <section class="receipt closed">
                  <div>🔒</div>
                  <h2>TOO LATE</h2>
                  <p>The moms are tallying the damage.</p>
                </section>
              `
              : `
                <form id="vote-form">
                  <div class="form-heading">
                    <h2>Choose the punishment</h2>
                    <div class="timer" id="timer">${secondsLeft}</div>
                  </div>
                  <div class="choices">
                    ${consequences
                      .map(
                        (choice) => `
                          <label class="choice ${selected === choice.id ? "selected" : ""}">
                            <input type="radio" name="consequence" value="${choice.id}" required />
                            <span class="choice-icon">${iconFor(choice.type)}</span>
                            <span class="choice-copy">
                              <strong>${escapeHTML(choice.title)}</strong>
                              <small>${escapeHTML(detailFor(choice))}</small>
                            </span>
                            <span class="radio"></span>
                          </label>
                        `,
                      )
                      .join("")}
                  </div>
                  <button type="submit" ${submitting ? "disabled" : ""}>
                    ${submitting ? "CASTING…" : "CAST VOTE"}
                  </button>
                  <p class="fine-print">One device, one vote. There are no appeals.</p>
                </form>
              `
        }
      </section>
    `;

    document.querySelectorAll(".choice input").forEach((input) => {
      input.addEventListener("change", () => {
        document.querySelectorAll(".choice").forEach((choice) => choice.classList.remove("selected"));
        input.closest(".choice").classList.add("selected");
      });
    });
    document.querySelector("#vote-form")?.addEventListener("submit", submitVote);
  }

  async function submitVote(event) {
    event.preventDefault();
    if (submitting || remainingSeconds(courtCase.closes_at) <= 0) return;

    const form = new FormData(event.currentTarget);
    const consequenceID = form.get("consequence");
    if (!consequences.some((choice) => choice.id === consequenceID)) return;

    submitting = true;
    render();
    const { data, error } = await supabase
      .from("votes")
      .insert({
        case_id: caseID,
        voter_id: voterID,
        consequence_id: consequenceID,
        voter_kind: "human",
      })
      .select()
      .single();

    submitting = false;
    if (error) {
      if (error.code === "23505") {
        const result = await supabase
          .from("votes")
          .select("*")
          .eq("case_id", caseID)
          .eq("voter_id", voterID)
          .single();
        existingVote = result.data;
        render();
        return;
      }
      renderError("Vote rejected", error.message);
      return;
    }

    existingVote = data;
    navigator.vibrate?.(80);
    render();
  }
}

async function fetchConsequences(supabase, caseID) {
  let result;
  for (let attempt = 0; attempt < 12; attempt += 1) {
    result = await supabase
      .from("consequences")
      .select("*")
      .eq("case_id", caseID)
      .order("created_at");
    if (result.error || result.data?.length) return result;
    await new Promise((resolve) => window.setTimeout(resolve, 250));
  }
  return result;
}

function updateCountdown(seconds) {
  const timer = document.querySelector("#timer");
  if (!timer) return;
  timer.textContent = seconds;
  timer.classList.toggle("urgent", seconds <= 5);
}

function remainingSeconds(closesAt) {
  return Math.max(0, Math.ceil((new Date(closesAt).getTime() - Date.now()) / 1000));
}

function getVoterID() {
  const key = "mommy-court-voter-id";
  let value = localStorage.getItem(key);
  if (!value) {
    value = crypto.randomUUID();
    localStorage.setItem(key, value);
  }
  return value;
}

function iconFor(type) {
  return {
    grounded: "🔒",
    orders: "💪",
    embarrass: "💬",
    waste_money: "🛒",
  }[type] ?? "⚠️";
}

function detailFor(choice) {
  const payload = choice.payload ?? {};
  if (choice.type === "grounded") return `${payload.duration_minutes ?? 120} minutes`;
  if (choice.type === "orders") return "Evidence required";
  if (choice.type === "waste_money") return `$${payload.price ?? "17.99"} purchase`;
  if (choice.type === "embarrass") {
    return `Send approved spicy pic to ${payload.recipient ?? "approved recipient"}`;
  }
  return "Pre-authorized";
}

function renderLobby() {
  app.innerHTML = `
    <section class="lobby">
      <div class="lobby-orbit">
        <span>👩🏻</span><span>👩🏽</span><span>👩🏼‍💼</span>
      </div>
      <p class="eyebrow">MOMMY COURT IS READY</p>
      <h1>Waiting for someone<br />to disappoint us.</h1>
      <p>Keep this page open. The next failed commitment will appear automatically.</p>
      <div class="lobby-status"><i></i> LISTENING FOR CASES</div>
    </section>
  `;
}

function renderError(title, message) {
  app.innerHTML = `
    <section class="error-card">
      <div>👩🏻‍⚖️</div>
      <p class="eyebrow">MOMMY COURT</p>
      <h1>${escapeHTML(title)}</h1>
      <p>${escapeHTML(message)}</p>
    </section>
  `;
}

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
