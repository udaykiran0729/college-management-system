import type { D1Database } from "@cloudflare/workers-types";

export interface AuthenticatedUser {
  id: number;
  username: string;
  roleId: number | null;
  studentId: number | null;
}

async function sha256(
  value: string,
): Promise<string> {
  const data = new TextEncoder().encode(value);

  const hash = await crypto.subtle.digest(
    "SHA-256",
    data,
  );

  return Array.from(new Uint8Array(hash))
    .map((byte) =>
      byte.toString(16).padStart(2, "0"),
    )
    .join("");
}

export async function hashToken(
  token: string,
): Promise<string> {
  return sha256(token);
}

export function getBearerToken(
  authorizationHeader?: string,
): string | null {
  if (!authorizationHeader) {
    return null;
  }

  const parts =
    authorizationHeader.trim().split(/\s+/);

  if (
    parts.length !== 2 ||
    parts[0].toLowerCase() !== "bearer"
  ) {
    return null;
  }

  return parts[1];
}

export async function getAuthenticatedUser(
  db: D1Database,
  token: string,
): Promise<AuthenticatedUser | null> {
  if (!token) {
    return null;
  }

  const tokenHash =
    await hashToken(token);

  const user = await db
    .prepare(
      `
      SELECT
        u.id,
        u.username,
        u.role_id AS roleId,
        u.student_id AS studentId
      FROM user_api_tokens t
      JOIN users u
        ON u.id = t.user_id
      WHERE t.token_hash = ?
        AND t.is_active = 1
        AND (
          t.expires_at IS NULL
          OR t.expires_at > CURRENT_TIMESTAMP
        )
      LIMIT 1
      `,
    )
    .bind(tokenHash)
    .first<AuthenticatedUser>();

  if (!user) {
    return null;
  }

  await db
    .prepare(
      `
      UPDATE user_api_tokens
      SET last_used_at = CURRENT_TIMESTAMP
      WHERE token_hash = ?
      `,
    )
    .bind(tokenHash)
    .run();

  return user;
}