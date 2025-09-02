import { Router } from "express";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";
import fetch from "node-fetch";
import "dotenv/config";

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

// --- OpenAI helpers ---
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_BASE = process.env.OPENAI_BASE_URL || "https://api.openai.com/v1";
const OPENAI_MODEL_JSON = process.env.OPENAI_MODEL_JSON || "gpt-4o-mini";
const OPENAI_MODEL_TEXT = process.env.OPENAI_MODEL_TEXT || "gpt-4o-mini";

async function openaiChatJSON(systemPrompt: string, userPrompt: string) {
  if (!OPENAI_API_KEY) throw new Error("missing_OPENAI_API_KEY");
  const resp = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL_JSON,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      response_format: { type: "json_object" },
      temperature: 0.3,
    }),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`openai_error ${resp.status}: ${text}`);
  }
  const data: any = await resp.json();
  const content = data.choices?.[0]?.message?.content || "{}";
  return JSON.parse(content);
}

async function openaiChatText(systemPrompt: string, userPrompt: string) {
  if (!OPENAI_API_KEY) throw new Error("missing_OPENAI_API_KEY");
  const resp = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL_TEXT,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.2,
    }),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`openai_error ${resp.status}: ${text}`);
  }
  const data: any = await resp.json();
  return data.choices?.[0]?.message?.content || "";
}

async function openaiChatStream(systemPrompt: string, userPrompt: string) {
  if (!OPENAI_API_KEY) throw new Error("missing_OPENAI_API_KEY");
  const resp = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL_TEXT,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.2,
      stream: true,
    }),
  });
  if (!resp.ok || !resp.body) {
    const text = await resp.text();
    throw new Error(`openai_stream_error ${resp.status}: ${text}`);
  }
  return resp;
}

type Aggregates = {
  timeframe: { from: string; to: string; months: number };
  totals: { expense: number; income: number; net: number };
  categories: Array<{ category: string; total: number }>;
  topMerchants: Array<{ merchant: string; total: number; count: number }>;
  outliers: Array<{ date: string; category: string; amount: number; note?: string }>;
  subs: Array<{ note: string; count: number; avg: number; monthlyEstimate: number; frequency: string }>;
};

async function computeAggregates(userId: string): Promise<Aggregates> {
  const col = await transactionsCollection();
  const since = new Date();
  since.setMonth(since.getMonth() - 12);
  const now = new Date();
  const txs = await col
    .find({ userId: new ObjectId(userId), date: { $gte: since } })
    .sort({ date: -1 })
    .limit(5000)
    .toArray();

  const expenses = txs.filter((t) => t.type === "expense");
  const income = txs.filter((t) => t.type === "income");
  const expenseSum = expenses.reduce((a, b) => a + (b.amount || 0), 0);
  const incomeSum = income.reduce((a, b) => a + (b.amount || 0), 0);
  const net = incomeSum - expenseSum;

  const catMap = new Map<string, number>();
  for (const t of expenses) catMap.set(t.category, (catMap.get(t.category) ?? 0) + t.amount);
  const categories = [...catMap.entries()].map(([category, total]) => ({ category, total })).sort((a, b) => b.total - a.total).slice(0, 15);

  const merchantMap = new Map<string, { total: number; count: number }>();
  for (const t of expenses) {
    const key = (t.merchantCanonical || t.note || "").toLowerCase().trim() || t.category;
    const val = merchantMap.get(key) || { total: 0, count: 0 };
    val.total += t.amount; val.count += 1; merchantMap.set(key, val);
  }
  const topMerchants = [...merchantMap.entries()].map(([merchant, v]) => ({ merchant, total: v.total, count: v.count }))
    .sort((a, b) => b.total - a.total).slice(0, 10);

  // Outliers (z-score > 2)
  const amounts = expenses.map((t) => t.amount);
  const mean = amounts.reduce((a, b) => a + b, 0) / Math.max(1, amounts.length);
  const variance = amounts.reduce((acc, x) => acc + Math.pow(x - mean, 2), 0) / Math.max(1, amounts.length);
  const std = Math.sqrt(variance);
  const threshold = mean + 2 * std;
  const outliers = expenses
    .filter((t) => t.amount > threshold)
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 10)
    .map((t) => ({ date: toISODateOnly(t.date), category: t.category, amount: t.amount, note: (t.note || undefined) }));

  // Subscriptions: repeating normalized notes with strict filtering to avoid groceries/etc.
  const byNote = new Map<string, { sum: number; count: number; dates: Date[]; categories: Map<string, number> }>();
  for (const t of expenses) {
    const k = (t.note || "").toLowerCase().trim();
    if (!k) continue;
    const v = byNote.get(k) || { sum: 0, count: 0, dates: [], categories: new Map() };
    v.sum += t.amount; v.count += 1; v.dates.push(t.date);
    v.categories.set(t.category, (v.categories.get(t.category) ?? 0) + 1);
    byNote.set(k, v);
  }
  const subscriptionKeywords = [
    // general
    "subscription","member","membership","plan","service","auto-pay",
    // streaming / media
    "netflix","hulu","disney","max","spotify","apple music","music","tv","stream","youtube","prime video",
    // cloud / software
    "icloud","google storage","google one","drive","dropbox","onedrive","adobe","microsoft","office","notion","slack","1password","github",
    // telecom / utilities / insurance / gym
    "att","at&t","verizon","t-mobile","xfinity","comcast","spectrum","internet","fiber","mobile","cell","phone","insurance","gym","fitness","peloton"
  ];
  const excludeKeywords = [
    // groceries / retail / restaurants / fuel etc.
    "grocery","groceries","market","supermarket","walmart","target","costco","kroger","safeway","aldi","heb","publix","winco",
    "mcdonald","starbucks","chipotle","restaurant","dining","uber","doordash","instacart","chevron","shell","exxon","gas","fuel","pharmacy","coffee"
  ];
  const allowedCategories = new Set([
    "Subscriptions","Utilities","Internet","Telecom","Mobile","Insurance","Streaming","Software","Music","TV","Cloud"
  ]);
  const bannedCategories = new Set([
    "Groceries","Grocery","Supermarket","Restaurants","Dining","Gas","Fuel","Retail","Coffee","Pharmacy","Convenience"
  ]);

  function looksLikeSubscription(note: string, cats: Map<string, number>): boolean {
    const n = note.toLowerCase();
    if (excludeKeywords.some((w) => n.includes(w))) return false;
    if (subscriptionKeywords.some((w) => n.includes(w))) return true;
    // category voting
    let topCat: string | undefined;
    let topCount = 0;
    for (const [c, cnt] of cats) { if (cnt > topCount) { topCount = cnt; topCat = c; } }
    if (topCat && allowedCategories.has(topCat)) return true;
    if (topCat && bannedCategories.has(topCat)) return false;
    return false;
  }

  const subs = [...byNote.entries()]
    .map(([note, v]) => {
      const s = [...v.dates].sort((a, b) => a.getTime() - b.getTime());
      const gaps = zipDiffDays(s);
      const med = median(gaps);
      const freq = gapToFreqLabel(med);
      const factor = freqToMonthlyFactor(freq);
      const avg = v.sum / Math.max(1, v.count);
      return { note, count: v.count, avg, monthlyEstimate: avg * factor, frequency: freq, cats: v.categories };
    })
    .filter((x) => x.count >= 3 && looksLikeSubscription(x.note, x.cats))
    .sort((a, b) => b.monthlyEstimate - a.monthlyEstimate)
    .slice(0, 10)
    .map((x) => ({ note: x.note, count: x.count, avg: x.avg, monthlyEstimate: x.monthlyEstimate, frequency: x.frequency }));

  return {
    timeframe: { from: toISODateOnly(since), to: toISODateOnly(now), months: 12 },
    totals: { expense: expenseSum, income: incomeSum, net },
    categories,
    topMerchants,
    outliers,
    subs,
  };
}

// ---- Health score (0..100) computed from aggregates and short-term volatility ----
function clamp(n: number, min: number, max: number) { return Math.max(min, Math.min(max, n)); }

async function computeHealthScore(userId: string) {
  const aggs = await computeAggregates(userId);
  const expense = aggs.totals.expense;
  const income = aggs.totals.income;
  const savingsRate = income > 0 ? clamp((income - expense) / income, -1, 1) : -1; // -1..1

  // Weekly volatility (last ~12 weeks)
  const col = await transactionsCollection();
  const since = new Date(); since.setDate(since.getDate() - 90);
  const txs = await col.find({ userId: new ObjectId(userId), date: { $gte: since } }).toArray();
  const expenses = txs.filter((t) => t.type === "expense");
  const weeks = new Map<string, number>();
  for (const t of expenses) {
    const d = new Date(t.date);
    // ISO week key yyyy-ww
    const yr = d.getUTCFullYear();
    const onejan = new Date(Date.UTC(yr,0,1));
    const week = Math.ceil((((d.getTime()-onejan.getTime())/86400000)+onejan.getUTCDay()+1)/7);
    const key = `${yr}-${String(week).padStart(2,'0')}`;
    weeks.set(key, (weeks.get(key) ?? 0) + (t.amount || 0));
  }
  const weekly = [...weeks.values()];
  const wMean = weekly.length ? weekly.reduce((a,b)=>a+b,0)/weekly.length : 0;
  const wStd = weekly.length ? Math.sqrt(weekly.reduce((acc,x)=>acc+Math.pow(x-wMean,2),0)/weekly.length) : 0;
  const volatility = wMean > 0 ? clamp(wStd / wMean, 0, 2) : 0; // coefficient of variation 0..2

  // Category concentration (share of top category)
  const totalCat = aggs.categories.reduce((a,b)=>a+b.total,0) || 1;
  const topShare = aggs.categories.length ? Math.max(...aggs.categories.map(c=>c.total))/totalCat : 0;

  // Subscription burden (estimate monthly subscriptions share)
  const subsMonthly = aggs.subs.reduce((a,b)=>a+(b.monthlyEstimate||0),0);
  const monthlySpend = expense / 12; // rough when 12m window; for current month we'd compute separately
  const subsShare = monthlySpend>0 ? clamp(subsMonthly / monthlySpend, 0, 1.5) : 0;

  // Component scores
  const components = [
    { key: "savings_rate", label: "Savings Rate", max: 40, score: clamp((savingsRate) * 200, 0, 40) }, // >=20% -> 40
    { key: "net_positive", label: "Net Positive Cashflow", max: 20, score: clamp(((income-expense)/Math.max(income,1))*20 + (income>expense?10:0), 0, 20) },
    { key: "stability", label: "Spending Stability", max: 20, score: clamp((1 - volatility/1.0) * 20, 0, 20) },
    { key: "diversification", label: "Category Diversification", max: 10, score: clamp((1 - topShare) * 10, 0, 10) },
    { key: "subs_burden", label: "Subscription Burden", max: 10, score: clamp((1 - subsShare) * 10, 0, 10) },
  ];
  const totalScore = Math.round(components.reduce((a,c)=>a+c.score,0));

  // Simple recommendations
  const recs: string[] = [];
  if (savingsRate < 0.1) recs.push("Increase savings rate towards 15–20% by trimming top categories.");
  if (volatility > 0.6) recs.push("Smooth spending by setting weekly caps on variable categories.");
  if (topShare > 0.35) recs.push("Reduce reliance on your top category; set a monthly budget.");
  if (subsShare > 0.2) recs.push("Review subscriptions; aim for < 15% of monthly spend.");

  return { score: totalScore, components: components.map(c=>({ key: c.key, label: c.label, score: Math.round(c.score), max: c.max })), recommendations: recs, totals: aggs.totals };
}

// ---- Proactive alerts (computed on demand) ----
type Alert = { id: string; title: string; body: string; severity: "info"|"warning"|"critical" };
async function computeAlerts(userId: string): Promise<Alert[]> {
  const col = await transactionsCollection();
  const now = new Date();
  const since = new Date(); since.setMonth(since.getMonth()-2);
  const txs = await col.find({ userId: new ObjectId(userId), date: { $gte: since } }).toArray();
  const expenses = txs.filter(t=>t.type==="expense");
  const alerts: Alert[] = [];

  // 1) Overspend this week vs last 4 weeks avg
  const dayMs = 86400000;
  const last7 = expenses.filter(t=> (now.getTime()-new Date(t.date).getTime())/dayMs <= 7);
  const prev28 = expenses.filter(t=> (now.getTime()-new Date(t.date).getTime())/dayMs > 7 && (now.getTime()-new Date(t.date).getTime())/dayMs <= 35);
  const sum = (arr:any[])=> arr.reduce((a,b)=>a+(b.amount||0),0);
  const w = sum(last7);
  const prevAvg = prev28.length ? (sum(prev28)/4) : 0;
  if (prevAvg>0 && w > prevAvg*1.2 && w > 100) {
    const pct = Math.round((w/prevAvg - 1)*100);
    alerts.push({ id: cryptoRandomId(), title: "This week trending high", body: `Spending is ${pct}% above your recent weekly average. Consider pausing a few discretionary purchases.`, severity: pct>40?"critical":"warning" });
  }

  // 2) Category spike this month vs last month
  const ym = now.toISOString().slice(0,7);
  const lastMonth = new Date(now.getFullYear(), now.getMonth()-1, 1);
  const lastMonthKey = lastMonth.toISOString().slice(0,7);
  const byCat = (arr:any[])=> {
    const m = new Map<string,number>();
    for (const t of arr) m.set(t.category, (m.get(t.category)||0)+t.amount);
    return m;
  };
  const thisMonth = expenses.filter(t=> toISODateOnly(t.date).startsWith(ym));
  const prevMonth = expenses.filter(t=> toISODateOnly(t.date).startsWith(lastMonthKey));
  const m1 = byCat(thisMonth), m0 = byCat(prevMonth);
  for (const [cat, amt] of m1) {
    const base = m0.get(cat)||0; if (amt>100 && base>0 && amt>base*1.3) {
      const pct = Math.round((amt/base - 1)*100);
      alerts.push({ id: cryptoRandomId(), title: `${cat} up ${pct}%`, body: `You're spending more on ${cat} this month ($${amt.toFixed(0)} vs $${base.toFixed(0)} last month).`, severity: pct>60?"warning":"info" });
    }
  }

  // 3) Large transaction alert in last 7 days
  const last7Tx = expenses.filter(t=> (now.getTime()-new Date(t.date).getTime())/dayMs <= 7);
  const amounts = expenses.map(t=>t.amount);
  const mean = amounts.length? amounts.reduce((a,b)=>a+b,0)/amounts.length: 0;
  const variance = amounts.length? amounts.reduce((acc,x)=>acc+Math.pow(x-mean,2),0)/amounts.length: 0;
  const std = Math.sqrt(variance);
  for (const t of last7Tx) {
    if (t.amount >= Math.max(300, mean + 2.5*std)) {
      alerts.push({ id: cryptoRandomId(), title: "Large purchase", body: `${toISODateOnly(t.date)} • ${t.category}${t.note?" • "+t.note:""}: $${t.amount.toFixed(2)}`, severity: "info" });
    }
  }

  // 4) Subscriptions burden
  const aggs = await computeAggregates(userId);
  const subsMonthly = aggs.subs.reduce((a,b)=>a+(b.monthlyEstimate||0),0);
  const monthlySpend = aggs.totals.expense/12;
  if (subsMonthly > 0 && monthlySpend>0 && subsMonthly/monthlySpend > 0.25) {
    alerts.push({ id: cryptoRandomId(), title: "Subscriptions heavy", body: `Estimated subscriptions ~$${subsMonthly.toFixed(0)}/mo may exceed 25% of monthly spending. Review to save.`, severity: "info" });
  }

  return alerts.slice(0, 8);
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

// --- GPT-powered structured insights ---
aiRouter.get("/api/ai/insights/gpt", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const aggs = await computeAggregates(userId);
    const system = "You are a financial insights assistant. Given user aggregates, produce JSON matching the schema and be concise, practical, and non-judgmental.";
    const user = JSON.stringify({
      schema: {
        type: "object",
        properties: {
          insights: {
            type: "array",
            items: {
              type: "object",
              properties: {
                id: { type: "string" },
                title: { type: "string" },
                description: { type: "string" },
                category: { enum: ["pattern", "anomaly", "prediction", "optimization"] },
                confidence: { type: "number" },
                actionable: { type: "boolean" },
              },
              required: ["id", "title", "description", "category", "confidence"],
            },
          },
          narrative: { type: "string" },
          savings_playbook: {
            type: "object",
            properties: {
              items: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    title: { type: "string" },
                    description: { type: "string" },
                    impact: { type: "string" },
                  },
                  required: ["title", "description"],
                },
              },
            },
          },
          budget: {
            type: "array",
            items: {
              type: "object",
              properties: {
                category: { type: "string" },
                suggestedMonthly: { type: "number" },
              },
              required: ["category", "suggestedMonthly"],
            },
          },
          subscriptions: {
            type: "array",
            items: {
              type: "object",
              properties: {
                note: { type: "string" },
                monthlyEstimate: { type: "number" },
                priority: { type: "string" },
              },
              required: ["note", "monthlyEstimate"],
            },
          },
        },
        required: ["insights"],
      },
      aggregates: aggs,
      instructions: "Fill id with any unique string. Provide 6-8 high quality insights. Put forecast explanation in narrative. Savings items should be concrete. Budget should cover top categories only. Subscriptions prioritize higher monthlyEstimate.",
    });
    const json = await openaiChatJSON(system, user);
    res.json(json);
  } catch (e) {
    console.error("/api/ai/insights/gpt error", e);
    res.status(500).json({ error: "gpt_insights_failed" });
  }
});

// --- GPT conversational assistant using aggregates context ---
aiRouter.post("/api/ai/assistant/gpt", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const prompt = String(req.body?.prompt || "").trim();
    if (!prompt) { res.status(400).json({ error: "missing_prompt" }); return; }
    const aggs = await computeAggregates(userId);
    const system = "You are a helpful finance assistant. Answer only using the provided aggregates. Be precise with numbers. If uncertain, say so. Keep replies under 8 sentences.";
    const user = `User question: ${prompt}\n\nAggregates JSON:\n${JSON.stringify(aggs)}`;
    const text = await openaiChatText(system, user);
    res.json({ reply: text });
  } catch (e) {
    console.error("/api/ai/assistant/gpt error", e);
    res.status(500).json({ error: "assistant_gpt_failed" });
  }
});

// --- GPT assistant streaming (SSE proxy) ---
aiRouter.post("/api/ai/assistant/gpt/stream", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const prompt = String(req.body?.prompt || "").trim();
    if (!prompt) { res.status(400).json({ error: "missing_prompt" }); return; }
    const aggs = await computeAggregates(userId);
    const system = "You are a helpful finance assistant. Answer only using the provided aggregates. Be precise with numbers. If uncertain, say so.";
    const user = `User question: ${prompt}\n\nAggregates JSON:\n${JSON.stringify(aggs)}`;

    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache, no-transform");
    res.setHeader("Connection", "keep-alive");
    res.flushHeaders?.();

    const upstream = await openaiChatStream(system, user);
    const body: any = upstream.body;
    // node-fetch returns a Node.js Readable stream; Web fetch returns a web stream
    if (body && typeof body.getReader === "function") {
      // Web stream
      const reader = body.getReader();
      const encoder = new TextEncoder();
      (async function pump() {
        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            res.write(value);
          }
          res.write(encoder.encode("\n\n"));
        } catch (e) {
          console.error("stream pipe error (web)", e);
        } finally {
          try { res.end(); } catch {}
        }
      })();
    } else if (body && typeof body.pipe === "function") {
      // Node Readable stream
      body.on("error", (e: any) => {
        console.error("stream pipe error (node)", e);
        try { res.end(); } catch {}
      });
      body.pipe(res);
    } else {
      console.error("No upstream body to stream");
      res.end();
    }
  } catch (e) {
    console.error("/api/ai/assistant/gpt/stream error", e);
    if (!res.headersSent) res.status(500).json({ error: "assistant_gpt_stream_failed" });
  }
});

// ---- Health score endpoint ----
aiRouter.get("/api/ai/health-score", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const payload = await computeHealthScore(userId);
    res.json(payload);
  } catch (e) {
    console.error("/api/ai/health-score error", e);
    res.status(500).json({ error: "health_score_failed" });
  }
});

// ---- Proactive alerts endpoint ----
aiRouter.get("/api/ai/alerts", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const alerts = await computeAlerts(userId);
    res.json({ alerts });
  } catch (e) {
    console.error("/api/ai/alerts error", e);
    res.status(500).json({ error: "alerts_failed" });
  }
});

// --- GPT Weekly Digest (on-demand) ---
aiRouter.get("/api/ai/digest/gpt", requireAppJWT, async (req, res) => {
  try {
    const userId = (req as any).userId as string;
    const aggs = await computeAggregates(userId);
    const system = "You create concise weekly money recaps. Use the aggregates to compare this week vs last, highlight notable categories or spikes, and list 1-3 action items. Keep it under 10 sentences.";
    const user = JSON.stringify({ aggregates: aggs, period: "weekly" });
    const text = await openaiChatText(system, user);
    res.json({ digest: text });
  } catch (e) {
    console.error("/api/ai/digest/gpt error", e);
    res.status(500).json({ error: "digest_failed" });
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
