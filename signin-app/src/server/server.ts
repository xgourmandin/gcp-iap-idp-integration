import express, { Request, Response } from "express";
import path from "path";

const app = express();
const PORT = parseInt(process.env.PORT ?? "8080", 10);

// ─── Static assets (bundle.js, styles.css, etc.) ──────────────────────────────
// In the Docker image, public/ is copied to dist/public/
app.use(express.static(path.join(__dirname, "..", "public")));

// ─── Firebase / Identity Platform config endpoint ─────────────────────────────
// The client-side code fetches this before initialising Firebase, so secrets
// are injected via environment variables rather than baked into the image.
//
// Required env vars (set in Cloud Run via Secret Manager or plain env):
//   FIREBASE_API_KEY       – Identity Platform Web API key
//   FIREBASE_PROJECT_ID    – GCP project ID
//   FIREBASE_AUTH_DOMAIN   – usually <project-id>.firebaseapp.com (optional)
app.get("/api/config", (_req: Request, res: Response) => {
  const { FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_AUTH_DOMAIN } =
    process.env;

  if (!FIREBASE_API_KEY || !FIREBASE_PROJECT_ID) {
    res.status(503).json({
      error:
        "Firebase configuration env vars (FIREBASE_API_KEY, FIREBASE_PROJECT_ID) are not set.",
    });
    return;
  }

  res.json({
    apiKey: FIREBASE_API_KEY,
    authDomain:
      FIREBASE_AUTH_DOMAIN ?? `${FIREBASE_PROJECT_ID}.firebaseapp.com`,
    projectId: FIREBASE_PROJECT_ID,
  });
});

// ─── Health check ──────────────────────────────────────────────────────────────
app.get("/healthz", (_req: Request, res: Response) => {
  res.sendStatus(200);
});

// ─── SPA fallback: serve index.html for all other GET routes ──────────────────
app.get("*", (_req: Request, res: Response) => {
  res.sendFile(path.join(__dirname, "..", "public", "index.html"));
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`IAP sign-in server listening on port ${PORT}`);
});
