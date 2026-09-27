import type { Context, Next } from "hono";
import type { D1Database } from "@cloudflare/workers-types";

import {
  getAuthenticatedUser,
  getBearerToken,
  type AuthenticatedUser,
} from "./user-auth";

export interface AuthContext {
  user: AuthenticatedUser;
}

export async function resolveAuthenticatedUser(
  db: D1Database,
  authorizationHeader?: string,
): Promise<AuthenticatedUser | null> {
  const token =
    getBearerToken(
      authorizationHeader,
    );

  if (!token) {
    return null;
  }

  return getAuthenticatedUser(
    db,
    token,
  );
}

export async function requireAuthenticatedUser(
  c: Context,
  next: Next,
) {
  const user =
    await resolveAuthenticatedUser(
      c.env.DB as D1Database,
      c.req.header("Authorization"),
    );

  if (!user) {
    return c.json(
      {
        success: false,
        message:
          "Invalid or expired authentication token",
      },
      401,
    );
  }

  c.set("authenticatedUser", user);

  await next();
}