import { Router } from "express";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";

export const aiRouter = Router();

type InsightCategory = "pattern" | "anomaly" | "prediction" | "optimization";
type InsightAction =
  | { type: "set_category_for_notes"; notes: string[]; category: string }
  | { type: "flag_anomalies"; transactionIds: string[] };

type AIInsight = {
  id: string;
  title: string;
  description: string;
  category: InsightCategory;
  confidence: number; // 0..1
  actionable?: boolean;
  action?: InsightAction;
};

function toISODateOnly(d: Date) {
  return d.toISOString().slice(0, 10);
}

aiRouter.get("/api/ai/insights", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const col = await transactionsCollection();
    const txs = await col
      .find({ userId: new ObjectId(userId) })
      .sort({ date: -1 })
      .limit(2000)
      .toArray();

    const insights: AIInsight[] = [];

    // Basic safety
    if (!txs.length) return res.json({ insights });

    // 1) Top spending category (expenses only)
    const expenses = txs.filter((t) => t.type === "expense");
    const catTotals = new Map<string, number>();
    for (const t of expenses) catTotals.set(t.category, (catTotals.get(t.category) ?? 0) + t.amount);
    if (catTotals.size) {
      let top: [string, number] | undefined;
      for (const [k, v] of catTotals) if (!top || v > top[1]) top = [k, v];
      const total = [...catTotals.values()].reduce((a, b) => a + b, 0) || 1;
      if (top) {
        const pct = (top[1] / total) * 100;
        insights.push({
          id: cryptoRandomId(),
          title: "Top Spending Category",
          description: `${pct.toFixed(1)}% of your spending goes to ${top[0]}. Consider setting a tighter budget or switching merchants for savings.`,
          category: "optimization",
          confidence: 0.85,
          actionable: true,
        });
      }
    }

    // 2) Monthly forecast (simple linear projection this month) + bills unknown (kept to spend only)
    {
      const now = new Date();
      const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
      const currentDay = now.getDate();
      const ym = now.toISOString().slice(0, 7); // yyyy-mm
      const monthExpenses = expenses.filter((t) => toISODateOnly(t.date).startsWith(ym));
      const spent = monthExpenses.reduce((a, b) => a + b.amount, 0);
      const dailyAvg = currentDay > 0 ? spent / currentDay : 0;
      const projected = dailyAvg * daysInMonth;
      insights.push({
        id: cryptoRandomId(),
        title: "Monthly Forecast",
        description: `Projected expense this month: $${projected.toFixed(2)} based on current pace.`,
        category: "prediction",
        confidence: 0.8,
        actionable: true,
      });
    }

    // 3) Amount anomalies (z-score > ~2)
    if (expenses.length >= 8) {
      const amounts = expenses.map((t) => t.amount);
      const mean = amounts.reduce((a, b) => a + b, 0) / amounts.length;
      const variance = amounts.reduce((acc, x) => acc + Math.pow(x - mean, 2), 0) / amounts.length;
      const std = Math.sqrt(variance);
      const threshold = mean + 2 * std;
      const outliers = expenses.filter((t) => t.amount > threshold).slice(0, 5);
      const outlierIds = outliers
        .map((t) => t._id)
        .filter(Boolean)
        .map((id) => String(id));
      for (const t of outliers) {
        insights.push({
          id: cryptoRandomId(),
          title: "Unusual Transaction",
          description: `$${t.amount.toFixed(2)} in ${t.category} looks high compared to your typical spend. Review if expected.`,
          category: "anomaly",
          confidence: 0.7,
          actionable: false,
        });
      }
      if (outlierIds.length) {
        insights.push({
          id: cryptoRandomId(),
          title: "Flag Anomalies",
          description: `Flag ${outlierIds.length} unusual transactions for follow-up.`,
          category: "anomaly",
          confidence: 0.65,
          actionable: true,
          action: { type: "flag_anomalies", transactionIds: outlierIds },
        });
      }
    }

    // 4) Potential subscriptions (category or repeating note text)
    {
      const byNote = new Map<string, number>();
      for (const t of expenses) {
        const key = (t.note ?? "").toLowerCase().trim();
        if (key) byNote.set(key, (byNote.get(key) ?? 0) + 1);
      }
      const recurring = [...byNote.entries()].filter(([, c]) => c >= 3).slice(0, 5);
      if (recurring.length) {
        const notes = recurring.map(([k]) => k).slice(0, 3);
        insights.push({
          id: cryptoRandomId(),
          title: "Subscription Review",
          description: `Detected ${recurring.length} possible subscriptions from repeating notes. Consider cancelling unused ones.`,
          category: "optimization",
          confidence: 0.6,
          actionable: true,
          action: { type: "set_category_for_notes", notes, category: "Subscriptions" },
        });
      }
    }

    res.json({ insights });
  } catch (e) {
    console.error("/api/ai/insights error", e);
    res.status(500).json({ error: "failed_to_generate_insights" });
  }
});

// Alias: POST generate → same as GET for now
aiRouter.post("/api/ai/insights/generate", requireAppJWT, async (req, res) => {
  (aiRouter as any).handle({ ...req, method: "GET", url: "/api/ai/insights" }, res, () => {});
});

aiRouter.post("/api/ai/insights/apply", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const action = req.body?.action as InsightAction | undefined;
    if (!action || typeof action !== "object") {
      res.status(400).json({ error: "missing_or_invalid_action" });
      return;
    }

    const col = await transactionsCollection();
    const userObjectId = new ObjectId(userId);
    const now = new Date();

    switch (action.type) {
      case "set_category_for_notes": {
        const notes = Array.isArray(action.notes) ? action.notes : [];
        const category = action.category || "Subscriptions";
        if (!notes.length) {
          res.status(400).json({ error: "notes_required" });
          return;
        }
        // Normalize note in same way as detection: lower + trim
        const norm = (s: string) => s.toLowerCase().trim();
        const normalizedNotes = notes.map(norm);
        const result = await col.updateMany(
          {
            userId: userObjectId,
            note: { $exists: true, $ne: null },
            $expr: {
              $in: [
                { $toLower: { $trim: { input: "$note" } } },
                normalizedNotes,
              ],
            },
          },
          { $set: { category, updatedAt: now } }
        );
        res.json({ success: true, modified: result.modifiedCount });
        return;
      }
      case "flag_anomalies": {
        const ids = Array.isArray(action.transactionIds) ? action.transactionIds : [];
        const objIds = ids
          .filter((s) => typeof s === "string" && ObjectId.isValid(s))
          .map((s) => new ObjectId(s));
        if (!objIds.length) {
          res.status(400).json({ error: "transactionIds_required" });
          return;
        }
        const result = await col.updateMany(
          {
            _id: { $in: objIds },
            userId: userObjectId,
          },
          { $set: { anomalyScore: 1, updatedAt: now } }
        );
        res.json({ success: true, modified: result.modifiedCount });
        return;
      }
      default:
        res.status(400).json({ error: "unsupported_action_type" });
        return;
    }
  } catch (e) {
    console.error("/api/ai/insights/apply error", e);
    res.status(500).json({ error: "apply_failed" });
  }
});

// --- Simple NL assistant: parse a prompt and compute stats over the user's transactions ---
aiRouter.post("/api/ai/assistant", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const prompt = String(req.body?.prompt || "").toLowerCase();
    if (!prompt.trim()) {
      res.status(400).json({ error: "missing_prompt" });
      return;
    }

    const col = await transactionsCollection();
    // Fetch a reasonable window (last 12 months)
    const since = new Date();
    since.setMonth(since.getMonth() - 12);
    const txs = await col
      .find({ userId: new ObjectId(userId), date: { $gte: since } })
      .sort({ date: -1 })
      .limit(5000)
      .toArray();

    const reply = answerPrompt(prompt, txs);
    res.json({ reply });
  } catch (e) {
    console.error("/api/ai/assistant error", e);
    res.status(500).json({ error: "assistant_failed" });
  }
});

function answerPrompt(prompt: string, txs: any[]): string {
  const { from, to, label } = parseTimeframe(prompt);
  const inRange = txs.filter((t) => t.date >= from && t.date <= to);

  // Try to detect category from prompt words
  const categories = new Set(inRange.map((t) => t.category));
  const category = detectCategory(prompt, categories);
  const filtered = category ? inRange.filter((t) => t.category.toLowerCase() === category.toLowerCase()) : inRange;

  // Intent routing by keywords
  const wantsTop = /top|biggest|largest|most/.test(prompt) && /category|categories/.test(prompt);
  const wantsAvg = /average|avg/.test(prompt) && /daily|day/.test(prompt);
  const wantsCompare = /compare|vs|versus/.test(prompt);
  const wantsListLargest = /largest|biggest|top\s+transactions/.test(prompt);
  const wantsIncome = /income|earned/.test(prompt);
  const wantsNet = /net/.test(prompt);
  const wantsCount = /how many|count/.test(prompt);
  const wantsSavings = /(how\s+can\s+i\s+)?save|saving|spend\s+less|cut\s+(back|spend|spending)|reduce\s+spend|lower\s+spend|optimi[sz]e/.test(prompt);

  if (wantsTop) {
    const byCat = aggregateByCategory(filtered.filter((t) => t.type === "expense"));
    const top = byCat.slice(0, 5).map(([c, total]) => `- ${c}: $${total.toFixed(2)}`).join("\n");
    return header(`Top categories ${label}`) + (top || "No expenses found.");
  }

  if (wantsSavings) {
    return savingsAdvice(filtered, label);
  }

  if (wantsAvg) {
    const days = Math.max(1, Math.ceil((to.getTime() - from.getTime()) / 86400000));
    const spend = sum(filtered.filter((t) => t.type === "expense"));
    return header(`Average daily spending ${label}`) + `$${(spend / days).toFixed(2)} per day.`;
  }

  if (wantsListLargest) {
    const largest = filtered
      .filter((t) => t.type === "expense")
      .sort((a, b) => b.amount - a.amount)
      .slice(0, 5)
      .map((t) => `- ${toDate(t.date)} • ${t.category}${t.note ? " • " + t.note : ""}: $${t.amount.toFixed(2)}`)
      .join("\n");
    return header(`Largest expenses ${label}`) + (largest || "No expenses found.");
  }

  if (wantsIncome) {
    const income = sum(filtered.filter((t) => t.type === "income"));
    return header(`Total income ${label}`) + `$${income.toFixed(2)}`;
  }

  if (wantsNet) {
    const income = sum(filtered.filter((t) => t.type === "income"));
    const expense = sum(filtered.filter((t) => t.type === "expense"));
    return header(`Net amount ${label}`) + `$${(income - expense).toFixed(2)} (income $${income.toFixed(2)} - expenses $${expense.toFixed(2)})`;
  }

  if (wantsCount) {
    return header(`Transactions ${label}`) + `${filtered.length} transactions${category ? ` in ${category}` : ""}.`;
  }

  // Default: total spending (optionally for a category)
  const spend = sum(filtered.filter((t) => t.type === "expense"));
  const catPart = category ? ` in ${category}` : "";
  return header(`Total spending ${label}${catPart}`) + `$${spend.toFixed(2)}`;
}

function savingsAdvice(txs: any[], label: string): string {
  const expenses = txs.filter((t) => t.type === "expense");
  if (!expenses.length) return header(`Savings opportunities ${label}`) + "No expenses found in this period.";

  const lines: string[] = [];

  // 1) Top categories to target (with 15% cut suggestion)
  const byCat = aggregateByCategory(expenses);
  const total = sum(expenses);
  const top = byCat.slice(0, 3);
  if (top.length) {
    lines.push(`Focus on your top categories ${label}:`);
    for (const [cat, amt] of top) {
      const pct = total > 0 ? (amt / total) * 100 : 0;
      const cut = amt * 0.15; // 15% cut suggestion
      lines.push(`- ${cat}: $${amt.toFixed(2)} (${pct.toFixed(1)}% of spend) → Save ~$${cut.toFixed(2)} by cutting 15%`);
    }
  }

  // 2) Possible subscriptions (repeating notes) and monthly estimate
  const subs = findRepeatingNotes(expenses);
  if (subs.length) {
    lines.push(`Review possible subscriptions ${label}:`);
    for (const s of subs.slice(0, 5)) {
      lines.push(`- ${s.note}: ~$${s.monthlyEstimate.toFixed(2)}/mo (avg $${s.avg.toFixed(2)}, ${s.count} charges, ${s.frequency})`);
    }
  }

  // 3) Frequent small purchases (habit candidates)
  const smalls = findFrequentSmalls(expenses);
  if (smalls.length) {
    lines.push("Reduce frequent small purchases:");
    for (const s of smalls.slice(0, 5)) {
      lines.push(`- ${s.note}: ${s.count}× avg $${s.avg.toFixed(2)} → Try batching or setting a weekly cap`);
    }
  }

  // 4) Anomaly spikes
  const spikes = findAmountOutliers(expenses).slice(0, 3);
  if (spikes.length) {
    lines.push("Watch for unusual spikes:");
    for (const t of spikes) {
      lines.push(`- ${toDate(t.date)} • ${t.category}${t.note ? " • " + t.note : ""}: $${t.amount.toFixed(2)}`);
    }
  }

  if (!lines.length) {
    const spend = sum(expenses);
    lines.push(`Total spending ${label}: $${spend.toFixed(2)}. Consider setting category caps and reviewing repeating charges.`);
  }

  return header(`Savings opportunities ${label}`) + lines.join("\n");
}

function findRepeatingNotes(expenses: any[]) {
  // Group by normalized note
  const isoNotes = expenses
    .map((t) => ({ ...t, _note: String(t.note ?? "").toLowerCase().trim() }))
    .filter((t) => t._note.length > 0);
  const byNote = new Map<string, any[]>();
  for (const t of isoNotes) byNote.set(t._note, [...(byNote.get(t._note) ?? []), t]);

  const res: { note: string; count: number; avg: number; frequency: string; monthlyEstimate: number }[] = [];
  for (const [note, items] of byNote) {
    if (items.length < 3) continue;
    const dates = items.map((t) => new Date(t.date) as Date).sort((a, b) => a.getTime() - b.getTime());
    if (dates.length < 3) continue;
    const gapsDays = zipDiffDays(dates);
    const medianGap = median(gapsDays);
    const freq = gapToFreqLabel(medianGap);
    const factor = freqToMonthlyFactor(freq);
    const avg = items.reduce((a, b) => a + b.amount, 0) / items.length;
    const monthly = avg * factor;
    res.push({ note, count: items.length, avg, frequency: freq, monthlyEstimate: monthly });
  }
  // rank by monthly estimate
  return res.sort((a, b) => b.monthlyEstimate - a.monthlyEstimate);
}

function findFrequentSmalls(expenses: any[]) {
  // candidates in $3..$20 with >=5 occurrences
  const isoNotes = expenses
    .filter((t) => t.amount >= 3 && t.amount <= 20)
    .map((t) => ({ ...t, _note: String(t.note ?? "").toLowerCase().trim() }))
    .filter((t) => t._note.length > 0);
  const byNote = new Map<string, any[]>();
  for (const t of isoNotes) byNote.set(t._note, [...(byNote.get(t._note) ?? []), t]);
  const res: { note: string; count: number; avg: number }[] = [];
  for (const [note, items] of byNote) {
    if (items.length < 5) continue;
    const avg = items.reduce((a, b) => a + b.amount, 0) / items.length;
    res.push({ note, count: items.length, avg });
  }
  return res.sort((a, b) => b.count - a.count);
}

function findAmountOutliers(expenses: any[]) {
  const amounts = expenses.map((t) => t.amount);
  const mean = amounts.reduce((a, b) => a + b, 0) / Math.max(1, amounts.length);
  const variance = amounts.reduce((acc, x) => acc + Math.pow(x - mean, 2), 0) / Math.max(1, amounts.length);
  const std = Math.sqrt(variance);
  const threshold = mean + 2 * std;
  return expenses.filter((t) => t.amount > threshold).sort((a, b) => b.amount - a.amount);
}

function zipDiffDays(dates: Date[]): number[] {
  const day = 24 * 60 * 60 * 1000;
  const res: number[] = [];
  for (let i = 1; i < dates.length; i++) {
    res.push(Math.round((dates[i].getTime() - dates[i - 1].getTime()) / day));
  }
  return res;
}

function median(xs: number[]): number {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function gapToFreqLabel(days: number): string {
  if (days >= 6 && days <= 8) return "weekly";
  if (days >= 24 && days <= 37) return "monthly";
  if (days >= 80 && days <= 100) return "quarterly";
  if (days >= 330 && days <= 400) return "yearly";
  return "monthly";
}

function freqToMonthlyFactor(freq: string): number {
  switch (freq) {
    case "weekly":
      return 4.33;
    case "monthly":
      return 1;
    case "quarterly":
      return 1 / 3;
    case "yearly":
      return 1 / 12;
    default:
      return 1;
  }
}

function parseTimeframe(prompt: string): { from: Date; to: Date; label: string } {
  const now = new Date();
  const to = now;
  const lc = prompt.toLowerCase();
  const from = new Date(0);
  let label = "(all time, last 12 months loaded)";

  function startOf(unit: "week" | "month" | "year") {
    const d = new Date(now);
    if (unit === "week") {
      const day = d.getDay();
      const diff = (day + 6) % 7; // Monday start
      d.setDate(d.getDate() - diff);
      d.setHours(0, 0, 0, 0);
      return d;
    }
    if (unit === "month") return new Date(d.getFullYear(), d.getMonth(), 1);
    return new Date(d.getFullYear(), 0, 1);
  }

  if (/today/.test(lc)) {
    const d = new Date(now); d.setHours(0,0,0,0);
    return { from: d, to, label: "today" };
  }
  if (/yesterday/.test(lc)) {
    const d = new Date(now); d.setDate(d.getDate() - 1); d.setHours(0,0,0,0);
    const end = new Date(d); end.setHours(23,59,59,999);
    return { from: d, to: end, label: "yesterday" };
  }
  if (/this week/.test(lc)) return { from: startOf("week"), to, label: "this week" };
  if (/last week/.test(lc)) {
    const end = new Date(startOf("week").getTime() - 1);
    const start = new Date(end); start.setDate(start.getDate() - 6); start.setHours(0,0,0,0);
    return { from: start, to: end, label: "last week" };
  }
  if (/this month/.test(lc)) return { from: startOf("month"), to, label: "this month" };
  if (/last month/.test(lc)) {
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
    return { from: start, to: end, label: "last month" };
  }
  if (/this year/.test(lc)) return { from: startOf("year"), to, label: "this year" };
  if (/last year/.test(lc)) return { from: new Date(now.getFullYear()-1,0,1), to: new Date(now.getFullYear()-1,11,31,23,59,59,999), label: "last year" };

  // fallback 90 days
  const start90 = new Date(now); start90.setDate(start90.getDate() - 90);
  return { from: start90, to, label: "(last 90 days)" };
}

function detectCategory(prompt: string, categories: Set<string>): string | undefined {
  const lc = prompt.toLowerCase();
  let best: string | undefined;
  for (const c of categories) {
    const cl = c.toLowerCase();
    if (lc.includes(cl)) { best = c; break; }
  }
  return best;
}

function aggregateByCategory(txs: any[]): [string, number][] {
  const map = new Map<string, number>();
  for (const t of txs) map.set(t.category, (map.get(t.category) ?? 0) + t.amount);
  return [...map.entries()].sort((a, b) => b[1] - a[1]);
}

function sum(txs: any[]): number { return txs.reduce((a, b) => a + (b.amount || 0), 0); }
function header(title: string) { return `"${title}"\n\n`; }
function toDate(d: Date) { return new Date(d).toISOString().slice(0,10); }

function cryptoRandomId() {
  // quick id without importing node:crypto types here
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}
