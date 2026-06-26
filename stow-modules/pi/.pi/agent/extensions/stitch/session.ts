/**
 * Lazy Stitch session wrapper.
 *
 * Creates the StitchToolClient on first use, reuses across calls.
 * Connection failures are surfaced as actionable messages.
 */

import { StitchToolClient } from "@google/stitch-sdk";
import type { StitchError } from "@google/stitch-sdk";

export class StitchSession {
  private client: StitchToolClient | null = null;
  private connectError: string | null = null;

  /** Ensure the client is connected. Returns error message string on failure, null on success. */
  async ensureConnected(): Promise<string | null> {
    if (this.connectError) return this.connectError;
    if (this.client) return null;

    if (!process.env.STITCH_API_KEY) {
      this.connectError = "STITCH_API_KEY env var not set. Get an API key from Google Cloud Console and enable the Stitch API.";
      return this.connectError;
    }

    try {
      this.client = new StitchToolClient();
      await this.client.connect();
      return null;
    } catch (err: unknown) {
      const msg = formatConnectError(err);
      this.connectError = msg;
      this.client = null;
      return msg;
    }
  }

  /** Call a tool through the connected client. Returns { result } or { error }. */
  async callTool(name: string, args: Record<string, unknown>): Promise<
    { result: unknown } | { error: string }
  > {
    const connErr = await this.ensureConnected();
    if (connErr) return { error: connErr };

    try {
      const result = await this.client!.callTool(name, args);
      return { result };
    } catch (err: unknown) {
      return { error: formatToolError(err, name) };
    }
  }

  /** Shut down the client connection. */
  async close(): Promise<void> {
    if (this.client) {
      try { await this.client.close(); } catch { /* ignore */ }
      this.client = null;
    }
  }
}

function formatConnectError(err: unknown): string {
  const msg = err instanceof Error ? err.message : String(err);
  const lower = msg.toLowerCase();

  if (lower.includes("fetch failed") || lower.includes("econnrefused") || lower.includes("enotfound")) {
    return "Cannot reach Stitch API. Check network connectivity.";
  }
  if (lower.includes("401") || lower.includes("unauthorized") || lower.includes("unauthenticated") || lower.includes("auth_failed")) {
    return "Stitch API key is invalid or expired. Check STITCH_API_KEY env var.";
  }
  if (lower.includes("403") || lower.includes("permission_denied")) {
    return "Stitch API key lacks permission. Verify the key has access to the Stitch API and the project.";
  }
  if (lower.includes("credentials_missing")) {
    return "STITCH_API_KEY env var is empty. Set it to a valid Google Cloud API key.";
  }

  return `Stitch connection failed: ${msg}`;
}

function formatToolError(err: unknown, toolName: string): string {
  // StitchError from the SDK has .code and .message
  const stitchErr = err as StitchError | undefined;
  if (stitchErr?.code) {
    const code = stitchErr.code;
    const msg = stitchErr.message ?? "Unknown error";

    if (code === "NOT_FOUND") return `Stitch: ${toolName} - not found. ${msg}`;
    if (code === "PERMISSION_DENIED") return `Stitch: ${toolName} - permission denied. ${msg}`;
    if (code === "RATE_LIMITED") return `Stitch: ${toolName} - rate limited. Wait and retry.`;
    if (code === "AUTH_FAILED") return `Stitch: ${toolName} - auth failed. Check STITCH_API_KEY.`;
    return `Stitch: ${toolName} failed (${code}): ${msg}`;
  }

  const msg = err instanceof Error ? err.message : String(err);
  return `Stitch: ${toolName} failed: ${msg}`;
}
