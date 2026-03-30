/**
 * IAP Sign-in App — Client entry point
 *
 * Drives the GCIP-IAP authentication flow using gcip-iap v2 + Firebase v9.
 *
 * gcip-iap v2 requires firebase@^9.8.3 as a peer dependency.
 * It internally uses compat-style Firebase Auth (auth.signOut(),
 * auth.onAuthStateChanged() as methods), so we use firebase/compat/*.
 * The three polyfills (whatwg-fetch, url-polyfill, promise-polyfill) are still
 * declared as peer deps by gcip-iap v2 and must be installed explicitly.
 *
 * Key difference from v0.1.x: handleSignedInUser() is gone — after startSignIn()
 * resolves, gcip-iap handles the token exchange and redirect to IAP automatically.
 */

// Firebase v9 compat layer — mirrors the v8 API surface expected by gcip-iap v2.
import firebase from "firebase/compat/app";
import "firebase/compat/auth";

import { Authentication, AuthenticationHandler, SelectedTenantInfo } from "gcip-iap";

// ─── Firebase app registry ────────────────────────────────────────────────────
// gcip-iap calls getAuth() once per (apiKey, tenantId) combination.
const appRegistry = new Map<string, firebase.app.App>();

function getOrCreateApp(apiKey: string, authDomain: string): firebase.app.App {
  if (appRegistry.has(apiKey)) return appRegistry.get(apiKey)!;
  const appName = `iap-signin-${apiKey.slice(0, 12)}`;
  const existing = firebase.apps.find((a) => a.name === appName);
  const app = existing ?? firebase.initializeApp({ apiKey, authDomain }, appName);
  appRegistry.set(apiKey, app);
  return app;
}

// ─── DOM helpers ─────────────────────────────────────────────────────────────
const $ = (id: string): HTMLElement => {
  const el = document.getElementById(id);
  if (!el) throw new Error(`#${id} not found`);
  return el;
};
const show = (id: string) => ($(id).style.display = "flex");
const hide = (id: string) => ($(id).style.display = "none");
const text = (id: string, t: string) => ($(id).textContent = t);

// ─── AuthenticationHandler (gcip-iap v2 interface) ───────────────────────────
class IAPAuthHandler implements AuthenticationHandler {
  private authDomain: string;

  constructor(authDomain: string) {
    this.authDomain = authDomain;
  }

  /**
   * Called by gcip-iap with the apiKey extracted from the IAP redirect URL.
   * Must return a Firebase Auth instance for that API key / tenant.
   */
  getAuth(apiKey: string, tenantId: string | null): firebase.auth.Auth {
    const app = getOrCreateApp(apiKey, this.authDomain);
    const auth = app.auth();
    auth.tenantId = tenantId; // null → project-level GCIP (no multi-tenancy)
    return auth;
  }

  /**
   * Called by gcip-iap when sign-in is required.
   * Show the UI and resolve with a UserCredential once the user completes sign-in.
   * gcip-iap v2 handles the token exchange with IAP and the redirect automatically
   * after this promise resolves — no handleSignedInUser() needed.
   */
  startSignIn(
    auth: firebase.auth.Auth,
    _tenant?: SelectedTenantInfo
  ): Promise<firebase.auth.UserCredential> {
    hide("loading-overlay");
    show("signin-form");

    return new Promise<firebase.auth.UserCredential>((resolve, reject) => {
      const signInWithProvider = async (provider: firebase.auth.AuthProvider) => {
        hide("signin-form");
        show("loading-overlay");
        text("loading-message", "Signing in…");
        try {
          const credential = await auth.signInWithPopup(provider);
          // gcip-iap takes over here: exchanges token with IAP then redirects.
          text("loading-message", "Verifying with IAP…");
          resolve(credential);
        } catch (err: unknown) {
          show("signin-form");
          hide("loading-overlay");
          reject(err);
        }
      };

      $("btn-google").addEventListener(
        "click",
        () => signInWithProvider(new firebase.auth.GoogleAuthProvider()),
        { once: true }
      );

      $("btn-auth0").addEventListener(
        "click",
        () => {
          const provider = new firebase.auth.OAuthProvider("oidc.auth0");
          provider.addScope("openid");
          provider.addScope("profile");
          provider.addScope("email");
          return signInWithProvider(provider);
        },
        { once: true }
      );
    });
  }

  /**
   * Called by gcip-iap after all tenants are signed out (full sign-out flow).
   * Not called on single-tenant sign-out.
   */
  async completeSignOut(): Promise<void> {
    for (const app of appRegistry.values()) {
      await app.auth().signOut();
    }
    hide("loading-overlay");
    show("signin-form");
    text("error-message", "You have been signed out.");
  }

  showProgressBar(): void { show("loading-overlay"); }
  hideProgressBar(): void { hide("loading-overlay"); }

  handleError(error: Error): void {
    hide("loading-overlay");
    show("error-banner");
    text("error-message", error.message ?? "An unexpected error occurred.");
    console.error("[IAP sign-in]", error);
  }
}

// ─── Bootstrap ───────────────────────────────────────────────────────────────
(async () => {
  try {
    const res = await fetch("/api/config");
    if (!res.ok) throw new Error(`Config fetch failed (HTTP ${res.status})`);
    const cfg: { apiKey: string; authDomain: string; projectId: string } =
      await res.json();

    // Pre-warm the Firebase app so getAuth() is synchronous on first call
    getOrCreateApp(cfg.apiKey, cfg.authDomain);

    const authentication = new Authentication(new IAPAuthHandler(cfg.authDomain));
    authentication.start();
  } catch (err: unknown) {
    console.error("[IAP sign-in] Bootstrap error:", err);
    try {
      show("error-banner");
      text(
        "error-message",
        err instanceof Error ? err.message : "Initialisation failed."
      );
    } catch {
      // DOM not ready yet
    }
  }
})();
