import {
  authorizeBusinessAction,
  authorizeBusinessActionOnRecord,
} from "./src/auth/advanced-rbac";
import {
  executeWorkflowTransition,
} from "./src/auth/workflow";
import { Hono } from "hono";
import type { Context, Next } from "hono";
import { cors } from "hono/cors";
import * as z from "zod";
import { zValidator } from "@hono/zod-validator";
import { swaggerUI } from "@hono/swagger-ui";
import { drizzle } from "drizzle-orm/d1";
import { eq } from "drizzle-orm";
import {
  getRoleFromToken,
  hasDocTypePermission,
  getDocTypePermissionScope,
  ROLE_NAMES,
  DOCTYPES,
  PERMISSIONS,
  type Role,
  type DocType,
  type Permission,
} from "./src/auth/rbac";

import { StudentDO } from "./src/do/StudentDO";
import { students } from "./src/db/schema";
import {
  getAuthenticatedUser,
  getBearerToken,
  hashToken,
  type AuthenticatedUser,
} from "./src/auth/user-auth";

/* =========================================================
   CLOUDFLARE BINDINGS
========================================================= */

type Bindings = {
  MY_APP_NAME: string;
  API_TOKEN: string;
  ADMIN_TOKEN?: string;
  HOD_TOKEN?: string;
  FACULTY_TOKEN?: string;
  STUDENT_TOKEN?: string;
  DB: D1Database;

  // IMPORTANT:
  // This tells TypeScript that the namespace contains StudentDO.
  STUDENT_DO: DurableObjectNamespace<StudentDO>;
};

/* =========================================================
   HONO APPLICATION
========================================================= */

const app = new Hono<{
  Bindings: Bindings;
  Variables: {
    role: Role;
    authenticatedUser: AuthenticatedUser;
  };
}>();
app.use(
  "*",
  cors({
    origin: "*",
    allowHeaders: ["Content-Type", "Authorization", "X-College-Username"],
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  }),
);

/* =========================================================
   ZOD SCHEMAS
========================================================= */

const StudentCreateSchema = z.object({
  name: z
    .string()
    .min(2, "Name must contain at least 2 characters"),

  age: z
    .number()
    .int("Age must be an integer")
    .min(1, "Age must be at least 1")
    .max(100, "Age must not exceed 100"),

  course: z
    .string()
    .min(2, "Course must contain at least 2 characters"),

  marks: z
    .number()
    .min(0, "Marks cannot be negative")
    .max(100, "Marks cannot exceed 100")
});

const StudentUpdateSchema =
  StudentCreateSchema.partial();

/* =========================================================
   AUTHENTICATION + RBAC

   Authentication answers: "Who are you?"
   RBAC answers: "What are you allowed to do?"
========================================================= */

async function authenticate(
  c: Context<{
    Bindings: Bindings;
    Variables: {
      role: Role;
      authenticatedUser: AuthenticatedUser;
    };
  }>,
  next: Next,
) {
  const authorization = c.req.header("Authorization");
  const token = getBearerToken(authorization);

  if (!token) {
    return c.json(
      {
        success: false,
        message: "Bearer token is required",
      },
      401,
    );
  }

  /*
   * The college uses shared role API tokens.
   *
   * Token answers: "Which role is being used?"
   * X-College-Username answers: "Which account is signing in?"
   *
   * Database-issued individual tokens remain supported for older API clients,
   * but they are not used by the normal College Management login.
   */
  const roleTokenRole = getRoleFromToken(token, c.env);
  const suppliedUsername = c.req.header("X-College-Username")?.trim();

  if (roleTokenRole) {
    if (suppliedUsername) {
      const account = await c.env.DB
        .prepare(
          `
          SELECT
            u.id AS id,
            u.username AS username,
            u.full_name AS full_name,
            u.email AS email,
            u.role_id AS role_id,
            u.student_id AS student_id,
            u.is_active AS is_active,
            r.role_name AS role_name
          FROM users u
          JOIN roles r ON r.id = u.role_id
          WHERE lower(u.username) = lower(?)
            AND u.is_active = 1
            AND r.is_active = 1
          LIMIT 1
          `,
        )
        .bind(suppliedUsername)
        .first<{
          id: number;
          username: string;
          full_name: string | null;
          email: string | null;
          role_id: number;
          student_id: number | null;
          is_active: number;
          role_name: Role;
        }>();

      if (!account) {
        return c.json(
          {
            success: false,
            message: "Username was not found in the college account directory",
          },
          404,
        );
      }

      if (account.role_name !== roleTokenRole) {
        return c.json(
          {
            success: false,
            message: "Username does not match the supplied account token.",
            authorization: {
              tokenRole: roleTokenRole,
              accountRole: account.role_name,
            },
          },
          403,
        );
      }

      const sharedTokenUser = {
        id: account.id,
        username: account.username,
        roleId: account.role_id,
        studentId: account.student_id,
        full_name: account.full_name,
        email: account.email,
      } as AuthenticatedUser;

      c.set("role", account.role_name);
      c.set("authenticatedUser", sharedTokenUser);
      await next();
      return;
    }

    // Role-only compatibility for existing API clients.
    c.set("role", roleTokenRole);
    await next();
    return;
  }

  /* Backward compatibility for older database-issued individual tokens. */
  const authenticatedUser = await getAuthenticatedUser(c.env.DB, token);

  if (authenticatedUser) {
    const roleRow = await c.env.DB
      .prepare(
        `
        SELECT role_name AS roleName
        FROM roles
        WHERE id = ?
          AND is_active = 1
        LIMIT 1
        `,
      )
      .bind(authenticatedUser.roleId)
      .first<{ roleName: Role }>();

    if (!roleRow) {
      return c.json(
        {
          success: false,
          message: "Authenticated user has no active primary role",
        },
        403,
      );
    }

    c.set("role", roleRow.roleName);
    c.set("authenticatedUser", authenticatedUser);
    await next();
    return;
  }

  return c.json(
    {
      success: false,
      message: "Invalid or expired authentication token",
    },
    401,
  );
}

async function requireAuthenticatedUser(
  c: Context<{
    Bindings: Bindings;
    Variables: {
      role: Role;
      authenticatedUser: AuthenticatedUser;
    };
  }>,
): Promise<AuthenticatedUser | Response> {
  const user = c.get("authenticatedUser");

  if (!user) {
    return c.json(
      {
        success: false,
        message:
          "A database-backed user API token is required for this operation",
      },
      401,
    );
  }

  return user;
}

function requireDocTypePermission(doctype: DocType, permission: Permission) {
  return async (c: Context<{ Bindings: Bindings; Variables: { role: Role; authenticatedUser: AuthenticatedUser } }>, next: Next) => {
    const role = c.get("role");

    if (!role) {
      return c.json({ success: false, message: "Unauthorized" }, 401);
    }

    const allowed = await hasDocTypePermission(c.env.DB, role, doctype, permission);

    if (!allowed) {
      return c.json({
        success: false,
        message: "Forbidden",
        authorization: { role, doctype, permission },
      }, 403);
    }

    const scope = await getEffectiveScope(c);
    if (scope instanceof Response) return scope;

    c.header("X-RBAC-Role", role);
    c.header("X-RBAC-DocType", doctype);
    c.header("X-RBAC-Permission", permission);
    c.header("X-RBAC-Scope", scope.mode);
    scopeHeader(c, scope);

    await next();
  };
}


type EffectiveScope = {
  mode: "SYSTEM" | "DEPARTMENT" | "OWN";
  departmentId?: number;
  studentId?: number;
};

async function getEffectiveScope(c: Context<{ Bindings: Bindings; Variables: { role: Role; authenticatedUser: AuthenticatedUser } }>): Promise<EffectiveScope | Response> {
  const role = c.get("role");

  if (role === "SUPER_ADMIN" || role === "ADMIN") {
    return { mode: "SYSTEM" };
  }

  const user = c.get("authenticatedUser");
  if (!user) {
    return c.json({ success: false, message: "A database-backed user account is required for scoped access" }, 401);
  }

  if (role === "STUDENT") {
    const row = await c.env.DB.prepare(`SELECT student_id FROM users WHERE id = ? AND is_active = 1 LIMIT 1`)
      .bind(user.id)
      .first<{ student_id: number | null }>();
    if (!row?.student_id) {
      return c.json({ success: false, message: "Student account is not linked to a student record" }, 403);
    }
    return { mode: "OWN", studentId: Number(row.student_id) };
  }

  if (role === "HOD" || role === "FACULTY") {
    const explicit = await c.env.DB.prepare(`
      SELECT usr.scope_id
      FROM user_scope_rules usr
      JOIN scope_types st ON st.id = usr.scope_type_id
      WHERE usr.user_id = ?
        AND st.scope_code = 'DEPARTMENT'
        AND usr.is_active = 1
        AND (usr.valid_from IS NULL OR usr.valid_from <= CURRENT_TIMESTAMP)
        AND (usr.valid_to IS NULL OR usr.valid_to >= CURRENT_TIMESTAMP)
      ORDER BY usr.id
      LIMIT 1
    `).bind(user.id).first<{ scope_id: number | null }>();

    if (explicit?.scope_id != null) {
      return { mode: "DEPARTMENT", departmentId: Number(explicit.scope_id) };
    }

    // Safe fallback: if the user email is linked to a faculty profile, use that department.
    const linked = await c.env.DB.prepare(`
      SELECT f.department_id
      FROM users u
      JOIN faculty f ON LOWER(TRIM(f.email)) = LOWER(TRIM(u.email))
      WHERE u.id = ? AND u.is_active = 1 AND f.is_active = 1
      LIMIT 1
    `).bind(user.id).first<{ department_id: number | null }>();

    if (linked?.department_id != null) {
      return { mode: "DEPARTMENT", departmentId: Number(linked.department_id) };
    }

    return c.json({
      success: false,
      message: "Your account is not assigned to an academic department",
      authorization: { role, scope: "DEPARTMENT" },
    }, 403);
  }

  return c.json({ success: false, message: "Unsupported authorization role" }, 403);
}

async function assertDocTypeRecordScope(
  c: Context<{ Bindings: Bindings; Variables: { role: Role; authenticatedUser: AuthenticatedUser } }>,
  doctype: DocType,
  recordId: number,
): Promise<EffectiveScope | Response> {
  const scope = await getEffectiveScope(c);
  if (scope instanceof Response) return scope;
  if (scope.mode === "SYSTEM") return scope;

  if (scope.mode === "OWN") {
    if (doctype === "Student") {
      if (scope.studentId === recordId) return scope;
    } else if (doctype === "Enrollment") {
      const row = await c.env.DB.prepare(`SELECT student_id FROM enrollments WHERE id = ? LIMIT 1`)
        .bind(recordId).first<{ student_id: number }>();
      if (row?.student_id === scope.studentId) return scope;
    } else if (doctype === "Attendance") {
      const row = await c.env.DB.prepare(`
        SELECT e.student_id
        FROM attendance a JOIN enrollments e ON e.id = a.enrollment_id
        WHERE a.id = ? LIMIT 1
      `).bind(recordId).first<{ student_id: number }>();
      if (row?.student_id === scope.studentId) return scope;
    }
    return c.json({ success: false, message: "Forbidden: record is outside your own scope" }, 403);
  }

  const departmentId = scope.departmentId!;
  let row: { department_id: number } | null = null;

  switch (doctype) {
    case "Branch":
      row = await c.env.DB.prepare(`SELECT d.id AS department_id FROM branches b JOIN departments d ON d.branch_id = b.id WHERE b.id = ? LIMIT 1`)
        .bind(recordId).first<{ department_id: number }>();
      break;
    case "Department":
      row = await c.env.DB.prepare(`SELECT id AS department_id FROM departments WHERE id = ? LIMIT 1`)
        .bind(recordId).first<{ department_id: number }>();
      break;
    case "Course":
      row = await c.env.DB.prepare(`SELECT department_id FROM courses WHERE id = ? LIMIT 1`)
        .bind(recordId).first<{ department_id: number }>();
      break;
    case "Student":
      row = await c.env.DB.prepare(`SELECT department_id FROM students WHERE id = ? LIMIT 1`)
        .bind(recordId).first<{ department_id: number }>();
      break;
    case "Faculty":
      row = await c.env.DB.prepare(`SELECT department_id FROM faculty WHERE id = ? LIMIT 1`)
        .bind(recordId).first<{ department_id: number }>();
      break;
    case "Subject":
      row = await c.env.DB.prepare(`
        SELECT c.department_id
        FROM subjects s JOIN courses c ON c.id = s.course_id
        WHERE s.id = ? LIMIT 1
      `).bind(recordId).first<{ department_id: number }>();
      break;
    case "Enrollment":
      row = await c.env.DB.prepare(`
        SELECT c.department_id
        FROM enrollments e JOIN courses c ON c.id = e.course_id
        WHERE e.id = ? LIMIT 1
      `).bind(recordId).first<{ department_id: number }>();
      break;
    case "Attendance":
      row = await c.env.DB.prepare(`
        SELECT c.department_id
        FROM attendance a
        JOIN enrollments e ON e.id = a.enrollment_id
        JOIN courses c ON c.id = e.course_id
        WHERE a.id = ? LIMIT 1
      `).bind(recordId).first<{ department_id: number }>();
      break;
    default:
      return c.json({ success: false, message: "This record type does not support department scope" }, 403);
  }

  if (row?.department_id === departmentId) return scope;
  return c.json({ success: false, message: "Forbidden: record is outside your department scope" }, 403);
}

function scopeHeader(c: Context<any>, scope: EffectiveScope) {
  c.header("X-RBAC-Effective-Scope", scope.mode);
  if (scope.departmentId != null) c.header("X-RBAC-Department-Id", String(scope.departmentId));
  if (scope.studentId != null) c.header("X-RBAC-Student-Id", String(scope.studentId));
}

/* =========================================================
   RBAC INFORMATION
========================================================= */

app.get("/rbac/roles", authenticate, async (c) => {
  const result = await c.env.DB.prepare(`
    SELECT r.id AS role_id, r.role_name, d.id AS doctype_id, d.doctype_name,
           p.id AS permission_id, p.action_name AS permission, drp.scope, drp.is_active
    FROM doctype_role_permissions drp
    JOIN roles r ON r.id = drp.role_id
    JOIN doctypes d ON d.id = drp.doctype_id
    JOIN permissions p ON p.id = drp.permission_id
    ORDER BY r.role_name, d.doctype_name, p.action_name
  `).all();

  return c.json({ success: true, count: result.results.length, roles: result.results });
});

app.get("/rbac/role-list", authenticate, async (c) => {
  const result = await c.env.DB.prepare(`SELECT id, role_name, description, is_active FROM roles ORDER BY id`).all();
  return c.json({ success: true, roles: result.results });
});

app.get("/rbac/doctypes", authenticate, async (c) => {
  const result = await c.env.DB.prepare(`SELECT id, doctype_name, description, is_active FROM doctypes ORDER BY id`).all();
  return c.json({ success: true, doctypes: result.results });
});

app.get("/rbac/permissions", authenticate, async (c) => {
  const result = await c.env.DB.prepare(`SELECT id, action_name, description FROM permissions ORDER BY id`).all();
  return c.json({ success: true, permissions: result.results });
});

app.get("/rbac/check", authenticate, async (c) => {
  const role = c.get("role");
  const doctypeParam = c.req.query("doctype");
  const permissionParam = c.req.query("permission");

  if (!doctypeParam || !permissionParam) {
    return c.json({ success: false, message: "doctype and permission query parameters are required", example: "/rbac/check?doctype=Student&permission=read" }, 400);
  }

  if (!DOCTYPES.includes(doctypeParam as DocType)) {
    return c.json({ success: false, message: "Invalid DocType", allowedDocTypes: DOCTYPES }, 400);
  }

  if (!PERMISSIONS.includes(permissionParam as Permission)) {
    return c.json({ success: false, message: "Invalid permission", allowedPermissions: PERMISSIONS }, 400);
  }

  const doctype = doctypeParam as DocType;
  const permission = permissionParam as Permission;
  const allowed = await hasDocTypePermission(c.env.DB, role, doctype, permission);
  const scope = await getDocTypePermissionScope(c.env.DB, role, doctype, permission);

  return c.json({ success: true, authorization: { role, doctype, permission, allowed, scope } });
});

app.post("/rbac/roles/create", authenticate, async (c) => {
  const currentRole = c.get("role");
  if (currentRole !== "SUPER_ADMIN") return c.json({ success: false, message: "Only SUPER_ADMIN can create roles" }, 403);

  const body = await c.req.json<{ role_name?: string; description?: string }>();
  if (!body.role_name?.trim()) return c.json({ success: false, message: "role_name is required" }, 400);

  try {
    const result = await c.env.DB.prepare(`INSERT INTO roles (role_name, description) VALUES (?, ?) RETURNING id, role_name, description, is_active`)
      .bind(body.role_name.trim().toUpperCase(), body.description?.trim() ?? null).first();
    return c.json({ success: true, message: "Role created successfully", role: result }, 201);
  } catch {
    return c.json({ success: false, message: "Role already exists" }, 409);
  }
});

app.post("/users/create", authenticate, async (c) => {
  const currentRole = c.get("role");
  if (currentRole !== "SUPER_ADMIN" && currentRole !== "ADMIN") return c.json({ success: false, message: "Only SUPER_ADMIN or ADMIN can create users" }, 403);

  const body = await c.req.json<{ username?: string; full_name?: string; email?: string; role_id?: number; student_id?: number | null }>();
  if (!body.username?.trim() || !body.full_name?.trim()) return c.json({ success: false, message: "username and full_name are required" }, 400);

  try {
    const result = await c.env.DB.prepare(`
      INSERT INTO users (username, full_name, email, role_id, student_id) VALUES (?, ?, ?, ?, ?)
      RETURNING id, username, full_name, email, role_id, student_id, is_active
    `).bind(body.username.trim(), body.full_name.trim(), body.email?.trim() ?? null, body.role_id ?? null, body.student_id ?? null).first();
    return c.json({ success: true, message: "User created successfully", user: result }, 201);
  } catch {
    return c.json({ success: false, message: "Username or email already exists" }, 409);
  }
});

app.post("/users/:id/tokens", authenticate, async (c) => {
  const currentRole = c.get("role");

  if (currentRole !== "SUPER_ADMIN" && currentRole !== "ADMIN") {
    return c.json(
      {
        success: false,
        message: "Only SUPER_ADMIN or ADMIN can create user API tokens",
      },
      403,
    );
  }

  const userId = Number(c.req.param("id"));

  if (!Number.isInteger(userId)) {
    return c.json(
      {
        success: false,
        message: "Invalid user ID",
      },
      400,
    );
  }

  const body = await c.req.json<{
    token_name?: string;
    expires_at?: string | null;
  }>().catch(() => ({} as { token_name?: string; expires_at?: string | null }));

  const user = await c.env.DB
    .prepare(
      `
      SELECT id, username, is_active
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
    )
    .bind(userId)
    .first<{ id: number; username: string; is_active: number }>();

  if (!user) {
    return c.json(
      { success: false, message: "User not found" },
      404,
    );
  }

  if (user.is_active !== 1) {
    return c.json(
      { success: false, message: "User is inactive" },
      403,
    );
  }

  const token = `smt_${crypto.randomUUID().replaceAll("-", "")}${crypto.randomUUID().replaceAll("-", "")}`;
  const tokenHash = await hashToken(token);
  const tokenName = body.token_name?.trim() || "default";

  await c.env.DB
    .prepare(
      `
      INSERT INTO user_api_tokens
        (user_id, token_hash, token_name, expires_at)
      VALUES (?, ?, ?, ?)
      `,
    )
    .bind(
      userId,
      tokenHash,
      tokenName,
      body.expires_at ?? null,
    )
    .run();

  return c.json(
    {
      success: true,
      message: "API token created. Store it securely; it will not be shown again.",
      token: {
        user_id: userId,
        username: user.username,
        token_name: tokenName,
        token,
        expires_at: body.expires_at ?? null,
      },
    },
    201,
  );
});

app.get("/users", authenticate, async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Administration access is restricted to system administrators" }, 403);
  const result = await c.env.DB.prepare(`
    SELECT u.id, u.username, u.full_name, u.email, u.role_id, r.role_name, u.is_active
    FROM users u LEFT JOIN roles r ON r.id = u.role_id
    ORDER BY u.id
  `).all();
  return c.json({ success: true, count: result.results.length, users: result.results });
});

app.get("/users/search", authenticate, async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Administration access is restricted to system administrators" }, 403);
  const search = c.req.query("q")?.trim() ?? "";
  if (!search) return c.json({ success: false, message: "Search query q is required" }, 400);

  const result = await c.env.DB.prepare(`
    SELECT u.id, u.username, u.full_name, u.email, u.role_id, r.role_name, u.is_active
    FROM users u LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.username LIKE ? OR u.full_name LIKE ? OR u.email LIKE ?
    ORDER BY u.id
  `).bind(`%${search}%`, `%${search}%`, `%${search}%`).all();

  return c.json({ success: true, count: result.results.length, users: result.results });
});

app.put("/users/:id/role", authenticate, async (c) => {
  if (c.get("role") !== "SUPER_ADMIN") return c.json({ success: false, message: "Only SUPER_ADMIN can assign roles" }, 403);

  const userId = Number(c.req.param("id"));
  if (!Number.isInteger(userId)) return c.json({ success: false, message: "Invalid user ID" }, 400);

  const body = await c.req.json<{ role_id?: number }>();
  if (!Number.isInteger(body.role_id)) return c.json({ success: false, message: "Valid role_id is required" }, 400);

  const roleExists = await c.env.DB.prepare(`SELECT id FROM roles WHERE id = ? AND is_active = 1`).bind(body.role_id).first();
  if (!roleExists) return c.json({ success: false, message: "Role not found" }, 404);

  const result = await c.env.DB.prepare(`
    UPDATE users SET role_id = ? WHERE id = ?
    RETURNING id, username, full_name, email, role_id, is_active
  `).bind(body.role_id, userId).first();

  if (!result) return c.json({ success: false, message: "User not found" }, 404);
  return c.json({ success: true, message: "Role assigned successfully", user: result });
});

app.post("/users/:id/scopes", authenticate, async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can assign user scopes" }, 403);
  const userId = Number(c.req.param("id"));
  if (!Number.isInteger(userId)) return c.json({ success: false, message: "Invalid user ID" }, 400);
  const body = await c.req.json<{ scope_code?: string; scope_id?: number | null; valid_from?: string | null; valid_to?: string | null }>();
  const scopeCode = body.scope_code?.trim().toUpperCase();
  if (!scopeCode || !["SYSTEM", "BRANCH", "DEPARTMENT", "COURSE", "OWN"].includes(scopeCode)) return c.json({ success: false, message: "Invalid scope_code" }, 400);
  const scopeType = await c.env.DB.prepare(`SELECT id FROM scope_types WHERE scope_code = ? AND is_active = 1 LIMIT 1`).bind(scopeCode).first<{ id: number }>();
  if (!scopeType) return c.json({ success: false, message: "Scope type not found" }, 404);
  const user = await c.env.DB.prepare(`SELECT id FROM users WHERE id = ? AND is_active = 1`).bind(userId).first();
  if (!user) return c.json({ success: false, message: "User not found" }, 404);
  if (scopeCode === "DEPARTMENT" && !Number.isInteger(body.scope_id)) return c.json({ success: false, message: "scope_id is required for DEPARTMENT scope" }, 400);
  await c.env.DB.prepare(`UPDATE user_scope_rules SET is_active = 0 WHERE user_id = ? AND scope_type_id = ?`).bind(userId, scopeType.id).run();
  const result = await c.env.DB.prepare(`INSERT INTO user_scope_rules (user_id, scope_type_id, scope_id, valid_from, valid_to, is_active) VALUES (?, ?, ?, ?, ?, 1) RETURNING *`).bind(userId, scopeType.id, body.scope_id ?? null, body.valid_from ?? null, body.valid_to ?? null).first();
  return c.json({ success: true, message: "User scope assigned successfully", scope: result }, 201);
});

app.post("/rbac/role-permissions/create", authenticate, async (c) => {
  if (c.get("role") !== "SUPER_ADMIN") return c.json({ success: false, message: "Only SUPER_ADMIN can assign permissions" }, 403);

  const body = await c.req.json<{ role_id?: number; doctype_id?: number; permission_id?: number; scope?: string }>();
  if (!Number.isInteger(body.role_id) || !Number.isInteger(body.doctype_id) || !Number.isInteger(body.permission_id)) {
    return c.json({ success: false, message: "role_id, doctype_id and permission_id are required" }, 400);
  }

  const scope = (body.scope ?? "ALL").toUpperCase();
  const validScopes = ["ALL", "SYSTEM", "BRANCH", "DEPARTMENT", "COURSE", "OWN"];
  if (!validScopes.includes(scope)) return c.json({ success: false, message: "Invalid scope", allowedScopes: validScopes }, 400);

  const references = await c.env.DB.prepare(`
    SELECT
      (SELECT id FROM roles WHERE id = ? AND is_active = 1) AS role_id,
      (SELECT id FROM doctypes WHERE id = ? AND is_active = 1) AS doctype_id,
      (SELECT id FROM permissions WHERE id = ?) AS permission_id
  `).bind(body.role_id, body.doctype_id, body.permission_id).first<{ role_id: number | null; doctype_id: number | null; permission_id: number | null }>();

  if (!references?.role_id || !references.doctype_id || !references.permission_id) {
    return c.json({ success: false, message: "Invalid role_id, doctype_id or permission_id" }, 404);
  }

  const existing = await c.env.DB.prepare(`SELECT id FROM doctype_role_permissions WHERE role_id = ? AND doctype_id = ? AND permission_id = ? LIMIT 1`).bind(body.role_id, body.doctype_id, body.permission_id).first<{ id: number }>();
  if (existing) {
    const result = await c.env.DB.prepare(`UPDATE doctype_role_permissions SET scope = ?, is_active = 1, effect = 'ALLOW' WHERE id = ? RETURNING id, role_id, doctype_id, permission_id, scope, is_active, effect`).bind(scope, existing.id).first();
    return c.json({ success: true, message: "DocType permission updated successfully", permission: result });
  }
  try {
    const result = await c.env.DB.prepare(`INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope) VALUES (?, ?, ?, ?) RETURNING id, role_id, doctype_id, permission_id, scope, is_active, effect`).bind(body.role_id, body.doctype_id, body.permission_id, scope).first();
    return c.json({ success: true, message: "DocType permission assigned successfully", permission: result }, 201);
  } catch (error) {
    return c.json({ success: false, message: "Unable to assign DocType permission", error: String(error) }, 409);
  }
});

/* =========================================================
   PROTECT D1 ROUTES
========================================================= */


app.use(
  "/student/*",
  authenticate
);

/* =========================================================
   PROTECT DURABLE OBJECT ROUTES
========================================================= */

app.use(
  "/do/student/*",
  authenticate
);

/* =========================================================
   DURABLE OBJECT HELPER
========================================================= */

function getStudentDO(
  c: {
    env: Bindings;
  }
): DurableObjectStub<StudentDO> {

  const id =
    c.env.STUDENT_DO.idFromName(
      "student-demo"
    );

  return c.env.STUDENT_DO.get(id);
}

/* =========================================================
   OPENAPI DOCUMENT
========================================================= */

const openApiDoc = {
  openapi: "3.0.0",

  info: {
    title:
      "Student Management API",

    version:
      "3.0.0",

    description:
      "Student Management API using Hono, Zod, Bearer Authentication, RBAC, Drizzle ORM, Cloudflare D1 and SQLite Durable Objects"
  },

  servers: [
    {
      url:
        "http://127.0.0.1:8787",

      description:
        "Local development server"
    }
  ],

  components: {

    securitySchemes: {

      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "API Token"
      }

    },

    schemas: {

      Student: {

        type: "object",

        properties: {

          id: {
            type: "integer",
            example: 1
          },

          name: {
            type: "string",
            example: "Rahul"
          },

          age: {
            type: "integer",
            example: 20
          },

          course: {
            type: "string",
            example: "Computer Science"
          },

          marks: {
            type: "integer",
            example: 85
          }

        }

      },

      StudentCreate: {

        type: "object",

        required: [
          "name",
          "age",
          "course",
          "marks"
        ],

        properties: {

          name: {
            type: "string",
            example: "Arjun"
          },

          age: {
            type: "integer",
            example: 22
          },

          course: {
            type: "string",
            example:
              "Software Engineering"
          },

          marks: {
            type: "integer",
            example: 88
          }

        }

      },

      StudentUpdate: {

        type: "object",

        properties: {

          name: {
            type: "string",
            example: "Arjun Kumar"
          },

          age: {
            type: "integer",
            example: 23
          },

          course: {
            type: "string",
            example:
              "Computer Science"
          },

          marks: {
            type: "integer",
            example: 95
          }

        }

      }

    }

  },

  paths: {

    "/rbac/roles": {
      get: {
        summary: "Get RBAC roles and permissions",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "RBAC matrix" },
          "401": { description: "Unauthorized" }
        }
      }
    },

    /* =====================================================
       HOME
    ===================================================== */

    "/": {

      get: {

        summary:
          "Get API information",

        responses: {

          "200": {
            description:
              "API information"
          }

        }

      }

    },

    /* =====================================================
       D1 CREATE
    ===================================================== */

    "/student/create": {

      post: {

        summary:
          "Create student in D1",

        security: [
          {
            bearerAuth: []
          }
        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentCreate"
              }

            }

          }

        },

        responses: {

          "201": {
            description:
              "Student created"
          },

          "400": {
            description:
              "Validation error"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       D1 READ ALL
    ===================================================== */

    "/student/all": {

      get: {

        summary:
          "Get all D1 students",

        security: [
          {
            bearerAuth: []
          }
        ],

        responses: {

          "200": {
            description:
              "Students returned"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       D1 READ ONE
    ===================================================== */

    "/student/{id}": {

      get: {

        summary:
          "Get D1 student by ID",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student found"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       D1 UPDATE
    ===================================================== */

    "/student/update/{id}": {

      put: {

        summary:
          "Update D1 student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentUpdate"
              }

            }

          }

        },

        responses: {

          "200": {
            description:
              "Student updated"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       D1 DELETE
    ===================================================== */

    "/student/delete/{id}": {

      delete: {

        summary:
          "Delete D1 student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student deleted"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       DURABLE OBJECT TEST
    ===================================================== */

    "/do/test": {

      get: {

        summary:
          "Test Durable Object SQLite",

        responses: {

          "200": {
            description:
              "Durable Object SQLite status"
          }

        }

      }

    },

    /* =====================================================
       DO CREATE
    ===================================================== */

    "/do/student/create": {

      post: {

        summary:
          "Create student in Durable Object SQLite",

        security: [
          {
            bearerAuth: []
          }
        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentCreate"
              }

            }

          }

        },

        responses: {

          "201": {
            description:
              "Student created in Durable Object"
          },

          "400": {
            description:
              "Validation error"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       DO READ ALL
    ===================================================== */

    "/do/student/all": {

      get: {

        summary:
          "Get all Durable Object students",

        security: [
          {
            bearerAuth: []
          }
        ],

        responses: {

          "200": {
            description:
              "Students returned"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       DO READ ONE
    ===================================================== */

    "/do/student/{id}": {

      get: {

        summary:
          "Get Durable Object student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student found"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       DO UPDATE
    ===================================================== */

    "/do/student/update/{id}": {

      put: {

        summary:
          "Update Durable Object student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentUpdate"
              }

            }

          }

        },

        responses: {

          "200": {
            description:
              "Student updated"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       DO DELETE
    ===================================================== */

    "/do/student/delete/{id}": {

      delete: {

        summary:
          "Delete Durable Object student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student deleted"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    }

  }
};

/* =========================================================
   SWAGGER JSON
========================================================= */

app.get(
  "/swagger.json",
  (c) => {
    return c.json(openApiDoc);
  }
);

/* =========================================================
   SWAGGER UI
========================================================= */

app.get(
  "/swagger",
  swaggerUI({
    url: "/swagger.json"
  })
);

/* =========================================================
   HOME
========================================================= */

app.get(
  "/",
  (c) => {

    return c.json({

      message:
        "Student Management API",

      application:
        c.env.MY_APP_NAME,

      databases: {

        d1:
          "Cloudflare D1 + SQLite",

        durableObject:
          "SQLite-backed Durable Object"

      },

      orm:
        "Drizzle ORM",

      authentication:
        "Bearer Token + RBAC",
      authorization: {
        roles: ROLE_NAMES,
        permissions: PERMISSIONS,
      doctypes: DOCTYPES,
      },

      validation:
        "Zod",

      documentation:
        "/swagger"

    });

  }
);

/* =========================================================
   COLLEGE MANAGEMENT - ACADEMIC APIs
========================================================= */

app.get("/me", authenticate, async (c) => {
  const user = c.get("authenticatedUser");
  return c.json({
    success: true,
    user,
    role: c.get("role") ?? null,
  });
});

app.get("/academic/overview", authenticate, async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const db = c.env.DB;
  let counts;
  if (scope.mode === "DEPARTMENT") {
    counts = await Promise.all([
      db.prepare("SELECT COUNT(*) AS count FROM branches b JOIN departments d ON d.branch_id = b.id WHERE d.id = ?").bind(scope.departmentId).first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM departments WHERE is_active = 1 AND id = ?").bind(scope.departmentId).first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM courses WHERE is_active = 1 AND department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM subjects s JOIN courses c ON c.id = s.course_id WHERE s.is_active = 1 AND c.department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM faculty WHERE is_active = 1 AND department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM students WHERE department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
    ]);
  } else if (scope.mode === "OWN") {
    counts = await Promise.all([
      Promise.resolve({ count: 0 }), Promise.resolve({ count: 0 }), Promise.resolve({ count: 0 }), Promise.resolve({ count: 0 }), Promise.resolve({ count: 0 }),
      db.prepare("SELECT COUNT(*) AS count FROM students WHERE id = ?").bind(scope.studentId).first<{ count: number }>(),
    ]);
  } else {
    counts = await Promise.all([
      db.prepare("SELECT COUNT(*) AS count FROM branches WHERE is_active = 1").first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM departments WHERE is_active = 1").first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM courses WHERE is_active = 1").first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM subjects WHERE is_active = 1").first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM faculty WHERE is_active = 1").first<{ count: number }>(),
      db.prepare("SELECT COUNT(*) AS count FROM students").first<{ count: number }>(),
    ]);
  }
  return c.json({ success: true, overview: { branches: Number(counts[0]?.count ?? 0), departments: Number(counts[1]?.count ?? 0), courses: Number(counts[2]?.count ?? 0), subjects: Number(counts[3]?.count ?? 0), faculty: Number(counts[4]?.count ?? 0), students: Number(counts[5]?.count ?? 0) } });
});

app.get("/academic/branches", authenticate, requireDocTypePermission("Branch", "read"), async (c) => {
  const scope = await getEffectiveScope(c);
  if (scope instanceof Response) return scope;
  const result = scope.mode === "DEPARTMENT"
    ? await c.env.DB.prepare(`
        SELECT DISTINCT b.id, b.branch_code, b.branch_name, b.description, b.is_active
        FROM branches b JOIN departments d ON d.branch_id = b.id
        WHERE d.id = ?
        ORDER BY b.branch_name
      `).bind(scope.departmentId).all()
    : await c.env.DB.prepare(`SELECT id, branch_code, branch_name, description, is_active FROM branches ORDER BY branch_name`).all();
  return c.json({ success: true, count: result.results.length, branches: result.results });
});

app.post("/academic/branches", authenticate, requireDocTypePermission("Branch", "create"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can create branches" }, 403);
  const body = await c.req.json<{ branch_code?: string; branch_name?: string; description?: string }>();
  if (!body.branch_code?.trim() || !body.branch_name?.trim()) return c.json({ success: false, message: "branch_code and branch_name are required" }, 400);
  try {
    const result = await c.env.DB.prepare(`INSERT INTO branches (branch_code, branch_name, description) VALUES (?, ?, ?) RETURNING id, branch_code, branch_name, description, is_active`)
      .bind(body.branch_code.trim().toUpperCase(), body.branch_name.trim(), body.description?.trim() ?? null).first();
    return c.json({ success: true, branch: result }, 201);
  } catch (error) { return c.json({ success: false, message: "Unable to create branch", error: String(error) }, 409); }
});

app.put("/academic/branches/:id", authenticate, requireDocTypePermission("Branch", "update"), async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid branch ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Branch", id);
  if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM") return c.json({ success: false, message: "Only system administrators can update branches" }, 403);
  const body = await c.req.json<{ branch_code?: string; branch_name?: string; description?: string; is_active?: number }>();
  const current = await c.env.DB.prepare("SELECT id FROM branches WHERE id = ?").bind(id).first();
  if (!current) return c.json({ success: false, message: "Branch not found" }, 404);
  await c.env.DB.prepare(`UPDATE branches SET branch_code = COALESCE(?, branch_code), branch_name = COALESCE(?, branch_name), description = COALESCE(?, description), is_active = COALESCE(?, is_active) WHERE id = ?`)
    .bind(body.branch_code?.trim().toUpperCase() ?? null, body.branch_name?.trim() ?? null, body.description ?? null, body.is_active ?? null, id).run();
  const branch = await c.env.DB.prepare("SELECT * FROM branches WHERE id = ?").bind(id).first();
  return c.json({ success: true, branch });
});

app.delete("/academic/branches/:id", authenticate, requireDocTypePermission("Branch", "delete"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can delete branches" }, 403);
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid branch ID" }, 400);
  const result = await c.env.DB.prepare("DELETE FROM branches WHERE id = ?").bind(id).run();
  if (!result.meta.changes) return c.json({ success: false, message: "Branch not found" }, 404);
  return c.json({ success: true, message: "Branch deleted successfully" });
});

app.get("/academic/departments", authenticate, requireDocTypePermission("Department", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const result = scope.mode === "DEPARTMENT"
    ? await c.env.DB.prepare(`SELECT d.id, d.department_code, d.department_name, d.branch_id, b.branch_code, b.branch_name, d.description, d.is_active FROM departments d JOIN branches b ON b.id = d.branch_id WHERE d.id = ? ORDER BY d.department_name`).bind(scope.departmentId).all()
    : await c.env.DB.prepare(`SELECT d.id, d.department_code, d.department_name, d.branch_id, b.branch_code, b.branch_name, d.description, d.is_active FROM departments d JOIN branches b ON b.id = d.branch_id ORDER BY d.department_name`).all();
  return c.json({ success: true, count: result.results.length, departments: result.results });
});

app.post("/academic/departments", authenticate, requireDocTypePermission("Department", "create"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can create departments" }, 403);
  const body = await c.req.json<{ department_code?: string; department_name?: string; branch_id?: number; description?: string }>();
  if (!body.department_code?.trim() || !body.department_name?.trim() || !Number.isInteger(body.branch_id)) return c.json({ success: false, message: "department_code, department_name and branch_id are required" }, 400);
  const branch = await c.env.DB.prepare("SELECT id FROM branches WHERE id = ? AND is_active = 1").bind(body.branch_id).first();
  if (!branch) return c.json({ success: false, message: "Branch not found" }, 404);
  try {
    const result = await c.env.DB.prepare(`INSERT INTO departments (department_code, department_name, branch_id, description) VALUES (?, ?, ?, ?) RETURNING *`).bind(body.department_code.trim().toUpperCase(), body.department_name.trim(), body.branch_id, body.description?.trim() ?? null).first();
    return c.json({ success: true, department: result }, 201);
  } catch (error) { return c.json({ success: false, message: "Unable to create department", error: String(error) }, 409); }
});

app.put("/academic/departments/:id", authenticate, requireDocTypePermission("Department", "update"), async (c) => {
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid department ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Department", id); if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM") return c.json({ success: false, message: "Only system administrators can update departments" }, 403);
  const body = await c.req.json<{ department_code?: string; department_name?: string; branch_id?: number; description?: string; is_active?: number }>();
  const current = await c.env.DB.prepare("SELECT id FROM departments WHERE id = ?").bind(id).first(); if (!current) return c.json({ success: false, message: "Department not found" }, 404);
  await c.env.DB.prepare(`UPDATE departments SET department_code = COALESCE(?, department_code), department_name = COALESCE(?, department_name), branch_id = COALESCE(?, branch_id), description = COALESCE(?, description), is_active = COALESCE(?, is_active) WHERE id = ?`).bind(body.department_code?.trim().toUpperCase() ?? null, body.department_name?.trim() ?? null, body.branch_id ?? null, body.description ?? null, body.is_active ?? null, id).run();
  const department = await c.env.DB.prepare(`SELECT d.*, b.branch_code, b.branch_name FROM departments d JOIN branches b ON b.id = d.branch_id WHERE d.id = ?`).bind(id).first();
  return c.json({ success: true, department });
});

app.delete("/academic/departments/:id", authenticate, requireDocTypePermission("Department", "delete"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can delete departments" }, 403);
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid department ID" }, 400);
  try { const result = await c.env.DB.prepare("DELETE FROM departments WHERE id = ?").bind(id).run(); if (!result.meta.changes) return c.json({ success: false, message: "Department not found" }, 404); return c.json({ success: true, message: "Department deleted successfully" }); }
  catch (error) { return c.json({ success: false, message: "Department cannot be deleted while dependent records exist", error: String(error) }, 409); }
});

app.get("/academic/courses", authenticate, requireDocTypePermission("Course", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const base = `SELECT c.id, c.course_code, c.course_name, c.department_id, d.department_code, d.department_name, b.id AS branch_id, b.branch_code, b.branch_name, c.duration_years, c.description, c.is_active FROM courses c JOIN departments d ON d.id = c.department_id JOIN branches b ON b.id = d.branch_id`;
  const result = scope.mode === "DEPARTMENT" ? await c.env.DB.prepare(`${base} WHERE c.department_id = ? ORDER BY c.course_name`).bind(scope.departmentId).all() : await c.env.DB.prepare(`${base} ORDER BY c.course_name`).all();
  return c.json({ success: true, count: result.results.length, courses: result.results });
});

app.post("/academic/courses", authenticate, requireDocTypePermission("Course", "create"), async (c) => {
  const body = await c.req.json<{ course_code?: string; course_name?: string; department_id?: number; duration_years?: number; description?: string }>();
  if (!body.course_code?.trim() || !body.course_name?.trim() || !Number.isInteger(body.department_id) || !Number.isInteger(body.duration_years)) return c.json({ success: false, message: "course_code, course_name, department_id and duration_years are required" }, 400);
  const access = await getEffectiveScope(c); if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM" && access.departmentId !== body.department_id) return c.json({ success: false, message: "Forbidden: course must belong to your department" }, 403);
  const department = await c.env.DB.prepare("SELECT id FROM departments WHERE id = ? AND is_active = 1").bind(body.department_id).first(); if (!department) return c.json({ success: false, message: "Department not found" }, 404);
  try { const course = await c.env.DB.prepare(`INSERT INTO courses (course_code, course_name, department_id, duration_years, description) VALUES (?, ?, ?, ?, ?) RETURNING *`).bind(body.course_code.trim().toUpperCase(), body.course_name.trim(), body.department_id, body.duration_years, body.description?.trim() ?? null).first(); return c.json({ success: true, course }, 201); }
  catch (error) { return c.json({ success: false, message: "Unable to create course", error: String(error) }, 409); }
});

app.put("/academic/courses/:id", authenticate, requireDocTypePermission("Course", "update"), async (c) => {
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid course ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Course", id); if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM") return c.json({ success: false, message: "Only system administrators can update courses" }, 403);
  const body = await c.req.json<{ course_code?: string; course_name?: string; department_id?: number; duration_years?: number; description?: string; is_active?: number }>();
  const current = await c.env.DB.prepare("SELECT id FROM courses WHERE id = ?").bind(id).first(); if (!current) return c.json({ success: false, message: "Course not found" }, 404);
  await c.env.DB.prepare(`UPDATE courses SET course_code = COALESCE(?, course_code), course_name = COALESCE(?, course_name), department_id = COALESCE(?, department_id), duration_years = COALESCE(?, duration_years), description = COALESCE(?, description), is_active = COALESCE(?, is_active) WHERE id = ?`).bind(body.course_code?.trim().toUpperCase() ?? null, body.course_name?.trim() ?? null, body.department_id ?? null, body.duration_years ?? null, body.description ?? null, body.is_active ?? null, id).run();
  const course = await c.env.DB.prepare(`SELECT c.*, d.department_code, d.department_name, b.branch_code, b.branch_name FROM courses c JOIN departments d ON d.id = c.department_id JOIN branches b ON b.id = d.branch_id WHERE c.id = ?`).bind(id).first(); return c.json({ success: true, course });
});

app.delete("/academic/courses/:id", authenticate, requireDocTypePermission("Course", "delete"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can delete courses" }, 403);
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid course ID" }, 400);
  try { const result = await c.env.DB.prepare("DELETE FROM courses WHERE id = ?").bind(id).run(); if (!result.meta.changes) return c.json({ success: false, message: "Course not found" }, 404); return c.json({ success: true, message: "Course deleted successfully" }); }
  catch (error) { return c.json({ success: false, message: "Course cannot be deleted while dependent records exist", error: String(error) }, 409); }
});

app.get("/academic/subjects", authenticate, requireDocTypePermission("Subject", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const base = `SELECT s.id, s.subject_code, s.subject_name, s.course_id, c.course_code, c.course_name, d.id AS department_id, d.department_code, d.department_name, b.id AS branch_id, b.branch_code, b.branch_name, s.semester, s.credits, s.is_active FROM subjects s JOIN courses c ON c.id = s.course_id JOIN departments d ON d.id = c.department_id JOIN branches b ON b.id = d.branch_id`;
  const result = scope.mode === "DEPARTMENT" ? await c.env.DB.prepare(`${base} WHERE c.department_id = ? ORDER BY c.course_name, s.semester, s.subject_name`).bind(scope.departmentId).all() : await c.env.DB.prepare(`${base} ORDER BY c.course_name, s.semester, s.subject_name`).all();
  return c.json({ success: true, count: result.results.length, subjects: result.results });
});

app.post("/academic/subjects", authenticate, requireDocTypePermission("Subject", "create"), async (c) => {
  const body = await c.req.json<{ subject_code?: string; subject_name?: string; course_id?: number; semester?: number; credits?: number }>();
  if (!body.subject_code?.trim() || !body.subject_name?.trim() || !Number.isInteger(body.course_id) || !Number.isInteger(body.semester)) return c.json({ success: false, message: "subject_code, subject_name, course_id and semester are required" }, 400);
  const access = await getEffectiveScope(c); if (access instanceof Response) return access;
  const course = await c.env.DB.prepare("SELECT id, department_id FROM courses WHERE id = ? AND is_active = 1").bind(body.course_id).first<{ id: number; department_id: number }>();
  if (!course) return c.json({ success: false, message: "Course not found" }, 404);
  if (access.mode !== "SYSTEM" && access.departmentId !== course.department_id) return c.json({ success: false, message: "Forbidden: subject must belong to your department" }, 403);
  try { const subject = await c.env.DB.prepare(`INSERT INTO subjects (subject_code, subject_name, course_id, semester, credits) VALUES (?, ?, ?, ?, ?) RETURNING *`).bind(body.subject_code.trim().toUpperCase(), body.subject_name.trim(), body.course_id, body.semester, body.credits ?? 3).first(); return c.json({ success: true, subject }, 201); }
  catch (error) { return c.json({ success: false, message: "Unable to create subject", error: String(error) }, 409); }
});

app.put("/academic/subjects/:id", authenticate, requireDocTypePermission("Subject", "update"), async (c) => {
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid subject ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Subject", id); if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM") return c.json({ success: false, message: "Only system administrators can update subjects" }, 403);
  const body = await c.req.json<{ subject_code?: string; subject_name?: string; course_id?: number; semester?: number; credits?: number; is_active?: number }>();
  const current = await c.env.DB.prepare("SELECT id FROM subjects WHERE id = ?").bind(id).first(); if (!current) return c.json({ success: false, message: "Subject not found" }, 404);
  await c.env.DB.prepare(`UPDATE subjects SET subject_code = COALESCE(?, subject_code), subject_name = COALESCE(?, subject_name), course_id = COALESCE(?, course_id), semester = COALESCE(?, semester), credits = COALESCE(?, credits), is_active = COALESCE(?, is_active) WHERE id = ?`).bind(body.subject_code?.trim().toUpperCase() ?? null, body.subject_name?.trim() ?? null, body.course_id ?? null, body.semester ?? null, body.credits ?? null, body.is_active ?? null, id).run();
  const subject = await c.env.DB.prepare(`SELECT s.*, c.course_code, c.course_name FROM subjects s JOIN courses c ON c.id = s.course_id WHERE s.id = ?`).bind(id).first(); return c.json({ success: true, subject });
});

app.delete("/academic/subjects/:id", authenticate, requireDocTypePermission("Subject", "delete"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can delete subjects" }, 403);
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid subject ID" }, 400);
  try { const result = await c.env.DB.prepare("DELETE FROM subjects WHERE id = ?").bind(id).run(); if (!result.meta.changes) return c.json({ success: false, message: "Subject not found" }, 404); return c.json({ success: true, message: "Subject deleted successfully" }); }
  catch (error) { return c.json({ success: false, message: "Subject cannot be deleted while dependent attendance exists", error: String(error) }, 409); }
});

app.get("/academic/faculty", authenticate, requireDocTypePermission("Faculty", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const base = `SELECT f.id, f.faculty_code, f.faculty_name, f.email, f.department_id, d.department_code, d.department_name, b.id AS branch_id, b.branch_code, b.branch_name, f.designation, f.is_active FROM faculty f JOIN departments d ON d.id = f.department_id JOIN branches b ON b.id = d.branch_id`;
  const result = scope.mode === "DEPARTMENT" ? await c.env.DB.prepare(`${base} WHERE f.department_id = ? ORDER BY f.faculty_name`).bind(scope.departmentId).all() : await c.env.DB.prepare(`${base} ORDER BY f.faculty_name`).all();
  return c.json({ success: true, count: result.results.length, faculty: result.results });
});

app.post("/academic/faculty", authenticate, requireDocTypePermission("Faculty", "create"), async (c) => {
  const role = c.get("role");
  if (!["ADMIN", "SUPER_ADMIN"].includes(role)) return c.json({ success: false, message: "Only system administrators can create faculty records" }, 403);
  const body = await c.req.json<{ faculty_code?: string; faculty_name?: string; email?: string; department_id?: number; designation?: string }>();
  if (!body.faculty_code?.trim() || !body.faculty_name?.trim() || !Number.isInteger(body.department_id)) return c.json({ success: false, message: "faculty_code, faculty_name and department_id are required" }, 400);
  try { const faculty = await c.env.DB.prepare(`INSERT INTO faculty (faculty_code, faculty_name, email, department_id, designation) VALUES (?, ?, ?, ?, ?) RETURNING *`).bind(body.faculty_code.trim().toUpperCase(), body.faculty_name.trim(), body.email?.trim() ?? null, body.department_id, body.designation?.trim() ?? null).first(); return c.json({ success: true, faculty }, 201); }
  catch (error) { return c.json({ success: false, message: "Unable to create faculty", error: String(error) }, 409); }
});

app.put("/academic/faculty/:id", authenticate, requireDocTypePermission("Faculty", "update"), async (c) => {
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid faculty ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Faculty", id); if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM") return c.json({ success: false, message: "Only system administrators can update faculty records" }, 403);
  const body = await c.req.json<{ faculty_code?: string; faculty_name?: string; email?: string; department_id?: number; designation?: string; is_active?: number }>();
  const current = await c.env.DB.prepare("SELECT id FROM faculty WHERE id = ?").bind(id).first(); if (!current) return c.json({ success: false, message: "Faculty not found" }, 404);
  await c.env.DB.prepare(`UPDATE faculty SET faculty_code = COALESCE(?, faculty_code), faculty_name = COALESCE(?, faculty_name), email = COALESCE(?, email), department_id = COALESCE(?, department_id), designation = COALESCE(?, designation), is_active = COALESCE(?, is_active) WHERE id = ?`).bind(body.faculty_code?.trim().toUpperCase() ?? null, body.faculty_name?.trim() ?? null, body.email?.trim() ?? null, body.department_id ?? null, body.designation?.trim() ?? null, body.is_active ?? null, id).run();
  const faculty = await c.env.DB.prepare(`SELECT * FROM faculty WHERE id = ?`).bind(id).first(); return c.json({ success: true, faculty });
});

app.delete("/academic/faculty/:id", authenticate, requireDocTypePermission("Faculty", "delete"), async (c) => {
  if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can delete faculty records" }, 403);
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ success: false, message: "Invalid faculty ID" }, 400);
  try { const result = await c.env.DB.prepare("DELETE FROM faculty WHERE id = ?").bind(id).run(); if (!result.meta.changes) return c.json({ success: false, message: "Faculty not found" }, 404); return c.json({ success: true, message: "Faculty deleted successfully" }); }
  catch (error) { return c.json({ success: false, message: "Faculty cannot be deleted while attendance references exist", error: String(error) }, 409); }
});

app.get("/academic/enrollments", authenticate, requireDocTypePermission("Enrollment", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const base = `SELECT e.id, e.student_id, s.name AS student_name, e.course_id, c.course_code, c.course_name, d.department_name, b.branch_name, e.academic_year, e.semester, e.enrollment_date, e.status FROM enrollments e JOIN students s ON s.id = e.student_id JOIN courses c ON c.id = e.course_id JOIN departments d ON d.id = c.department_id JOIN branches b ON b.id = d.branch_id`;
  let result;
  if (scope.mode === "DEPARTMENT") result = await c.env.DB.prepare(`${base} WHERE c.department_id = ? ORDER BY e.id DESC`).bind(scope.departmentId).all();
  else if (scope.mode === "OWN") result = await c.env.DB.prepare(`${base} WHERE e.student_id = ? ORDER BY e.id DESC`).bind(scope.studentId).all();
  else result = await c.env.DB.prepare(`${base} ORDER BY e.id DESC`).all();
  return c.json({ success: true, count: result.results.length, enrollments: result.results });
});

app.post("/academic/enrollments", authenticate, requireDocTypePermission("Enrollment", "create"), async (c) => {
  const body = await c.req.json<{ student_id?: number; course_id?: number; academic_year?: string; semester?: number; status?: string }>();
  if (!Number.isInteger(body.student_id) || !Number.isInteger(body.course_id) || !body.academic_year?.trim() || !Number.isInteger(body.semester)) return c.json({ success: false, message: "student_id, course_id, academic_year and semester are required" }, 400);
  const access = await getEffectiveScope(c); if (access instanceof Response) return access;
  if (access.mode === "DEPARTMENT") {
    const course = await c.env.DB.prepare(`SELECT department_id FROM courses WHERE id = ?`).bind(body.course_id).first<{ department_id: number }>();
    if (!course || course.department_id !== access.departmentId) return c.json({ success: false, message: "Forbidden: enrollment course is outside your department" }, 403);
  } else if (access.mode === "OWN" && body.student_id !== access.studentId) {
    return c.json({ success: false, message: "Forbidden: you can only enroll your own student record" }, 403);
  }
  try { const enrollment = await c.env.DB.prepare(`INSERT INTO enrollments (student_id, course_id, academic_year, semester, status) VALUES (?, ?, ?, ?, ?) RETURNING *`).bind(body.student_id, body.course_id, body.academic_year.trim(), body.semester, body.status?.trim().toUpperCase() ?? "ACTIVE").first(); return c.json({ success: true, enrollment }, 201); }
  catch (error) { return c.json({ success: false, message: "Unable to create enrollment", error: String(error) }, 409); }
});

app.post("/attendance", authenticate, async (c) => {
  const role = c.get("role");
  if (!["FACULTY", "HOD", "ADMIN", "SUPER_ADMIN"].includes(role)) return c.json({ success: false, message: "Only faculty and authorized administrators can create attendance records" }, 403);
  const access = await getEffectiveScope(c); if (access instanceof Response) return access;
  const body = await c.req.json<{ enrollment_id?: number; subject_id?: number; attendance_date?: string; status?: string }>();
  if (!Number.isInteger(body.enrollment_id) || !Number.isInteger(body.subject_id) || !body.attendance_date?.trim()) return c.json({ success: false, message: "enrollment_id, subject_id and attendance_date are required" }, 400);
  const enrollment = await c.env.DB.prepare(`SELECT e.id, e.student_id, e.course_id, c.department_id FROM enrollments e JOIN courses c ON c.id = e.course_id WHERE e.id = ? AND UPPER(e.status) = 'ACTIVE' LIMIT 1`).bind(body.enrollment_id).first<{ id: number; student_id: number; course_id: number; department_id: number }>();
  if (!enrollment) return c.json({ success: false, message: "Active enrollment not found" }, 404);
  if (access.mode === "DEPARTMENT" && enrollment.department_id !== access.departmentId) return c.json({ success: false, message: "Forbidden: attendance record is outside your department" }, 403);
  if (access.mode === "OWN" && enrollment.student_id !== access.studentId) return c.json({ success: false, message: "Forbidden: attendance record is outside your own scope" }, 403);
  const subject = await c.env.DB.prepare(`SELECT id, course_id FROM subjects WHERE id = ? AND is_active = 1 LIMIT 1`).bind(body.subject_id).first<{ id: number; course_id: number }>();
  if (!subject) return c.json({ success: false, message: "Subject not found" }, 404);
  if (subject.course_id !== enrollment.course_id) return c.json({ success: false, message: "Selected subject does not belong to the student's enrolled course" }, 409);
  const pendingState = await c.env.DB.prepare(`SELECT id FROM workflow_states WHERE state_code = 'PENDING' LIMIT 1`).first<{ id: number }>();
  let markedByFacultyId: number | null = null;
  if (role === "FACULTY") {
    const user = c.get("authenticatedUser");
    const linked = user ? await c.env.DB.prepare(`SELECT f.id FROM users u JOIN faculty f ON LOWER(TRIM(f.email)) = LOWER(TRIM(u.email)) WHERE u.id = ? AND f.is_active = 1 LIMIT 1`).bind(user.id).first<{ id: number }>() : null;
    if (linked?.id) markedByFacultyId = linked.id;
  }
  try {
    const attendance = await c.env.DB.prepare(`INSERT INTO attendance (enrollment_id, subject_id, attendance_date, status, marked_by_faculty_id, workflow_state_id) VALUES (?, ?, ?, ?, ?, ?) RETURNING *`).bind(body.enrollment_id, body.subject_id, body.attendance_date.trim(), body.status?.trim().toUpperCase() || "PRESENT", markedByFacultyId, pendingState?.id ?? null).first();
    return c.json({ success: true, message: "Attendance record created", attendance }, 201);
  } catch (error) { return c.json({ success: false, message: "Unable to create attendance record", error: String(error) }, 409); }
});

app.get("/attendance/all", authenticate, requireDocTypePermission("Attendance", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const base = `SELECT a.id, a.enrollment_id, a.subject_id, a.attendance_date, a.status, a.marked_by_faculty_id, s.name AS student_name, c.course_name, sub.subject_code, sub.subject_name, f.faculty_name FROM attendance a JOIN enrollments e ON e.id = a.enrollment_id JOIN students s ON s.id = e.student_id JOIN subjects sub ON sub.id = a.subject_id JOIN courses c ON c.id = sub.course_id LEFT JOIN faculty f ON f.id = a.marked_by_faculty_id`;
  let result;
  if (scope.mode === "DEPARTMENT") result = await c.env.DB.prepare(`${base} WHERE c.department_id = ? ORDER BY a.attendance_date DESC, a.id DESC`).bind(scope.departmentId).all();
  else if (scope.mode === "OWN") result = await c.env.DB.prepare(`${base} WHERE e.student_id = ? ORDER BY a.attendance_date DESC, a.id DESC`).bind(scope.studentId).all();
  else result = await c.env.DB.prepare(`${base} ORDER BY a.attendance_date DESC, a.id DESC`).all();
  return c.json({ success: true, count: result.results.length, attendance: result.results });
});

app.get("/academic/dashboard", authenticate, async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  const queries = scope.mode === "DEPARTMENT" ? [
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM students WHERE department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM faculty WHERE is_active = 1 AND department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM courses WHERE is_active = 1 AND department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM subjects s JOIN courses c ON c.id = s.course_id WHERE s.is_active = 1 AND c.department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM attendance a JOIN enrollments e ON e.id = a.enrollment_id JOIN courses c ON c.id = e.course_id WHERE c.department_id = ?").bind(scope.departmentId).first<{ count: number }>(),
  ] : scope.mode === "OWN" ? [
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM students WHERE id = ?").bind(scope.studentId).first<{ count: number }>(),
    Promise.resolve({ count: 0 }), Promise.resolve({ count: 0 }), Promise.resolve({ count: 0 }),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM attendance a JOIN enrollments e ON e.id = a.enrollment_id WHERE e.student_id = ?").bind(scope.studentId).first<{ count: number }>(),
  ] : [
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM students").first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM faculty WHERE is_active = 1").first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM courses WHERE is_active = 1").first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM subjects WHERE is_active = 1").first<{ count: number }>(),
    c.env.DB.prepare("SELECT COUNT(*) AS count FROM attendance").first<{ count: number }>(),
  ];
  const [students, faculty, courses, subjects, attendance] = await Promise.all(queries);
  return c.json({ success: true, dashboard: { students: Number(students?.count ?? 0), faculty: Number(faculty?.count ?? 0), courses: Number(courses?.count ?? 0), subjects: Number(subjects?.count ?? 0), attendanceRecords: Number(attendance?.count ?? 0) } });
});

/* =========================================================
   D1 + DRIZZLE
   CREATE
========================================================= */

app.post(
  "/student/create",
  authenticate,
  requireDocTypePermission("Student", "create"),
  zValidator("json", StudentCreateSchema),
  async (c) => {
    if (!["ADMIN", "SUPER_ADMIN"].includes(c.get("role"))) return c.json({ success: false, message: "Only system administrators can create student records" }, 403);
    const body = c.req.valid("json");
    const result = await c.env.DB.prepare(`INSERT INTO students (name, age, course, marks) VALUES (?, ?, ?, ?) RETURNING *`)
      .bind(body.name, body.age, body.course, body.marks).first();
    return c.json({ message: "Student created successfully in D1", student: result }, 201);
  },
);

app.get("/student/all", authenticate, requireDocTypePermission("Student", "read"), async (c) => {
  const scope = await getEffectiveScope(c); if (scope instanceof Response) return scope;
  let result;
  if (scope.mode === "DEPARTMENT") {
    result = await c.env.DB.prepare(`SELECT * FROM students WHERE department_id = ? ORDER BY id`).bind(scope.departmentId).all();
  } else if (scope.mode === "OWN") {
    result = await c.env.DB.prepare(`SELECT * FROM students WHERE id = ? ORDER BY id`).bind(scope.studentId).all();
  } else {
    result = await c.env.DB.prepare(`SELECT * FROM students ORDER BY id`).all();
  }
  return c.json({ count: result.results.length, students: result.results });
});

app.get("/student/:id", authenticate, requireDocTypePermission("Student", "read"), async (c) => {
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ error: "Invalid student ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Student", id); if (access instanceof Response) return access;
  const result = await c.env.DB.prepare(`SELECT * FROM students WHERE id = ? LIMIT 1`).bind(id).first();
  if (!result) return c.json({ error: "Student not found" }, 404);
  return c.json(result);
});

app.put(
  "/student/update/:id",
  authenticate,
  requireDocTypePermission("Student", "update"),
  zValidator("json", StudentUpdateSchema),
  async (c) => {
    const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ error: "Invalid student ID" }, 400);
    const access = await assertDocTypeRecordScope(c, "Student", id); if (access instanceof Response) return access;
    const body = c.req.valid("json");
    const existing = await c.env.DB.prepare(`SELECT id FROM students WHERE id = ? LIMIT 1`).bind(id).first();
    if (!existing) return c.json({ error: "Student not found" }, 404);
    const result = await c.env.DB.prepare(`
      UPDATE students SET
        name = COALESCE(?, name),
        age = COALESCE(?, age),
        course = COALESCE(?, course),
        marks = COALESCE(?, marks)
      WHERE id = ? RETURNING *
    `).bind(body.name ?? null, body.age ?? null, body.course ?? null, body.marks ?? null, id).first();
    return c.json({ message: "Student updated successfully in D1", student: result });
  },
);

app.delete("/student/delete/:id", authenticate, requireDocTypePermission("Student", "delete"), async (c) => {
  const id = Number(c.req.param("id")); if (!Number.isInteger(id)) return c.json({ error: "Invalid student ID" }, 400);
  const access = await assertDocTypeRecordScope(c, "Student", id); if (access instanceof Response) return access;
  if (access.mode !== "SYSTEM") return c.json({ success: false, message: "Student deletion is restricted to system administrators" }, 403);
  const result = await c.env.DB.prepare(`DELETE FROM students WHERE id = ? RETURNING *`).bind(id).first();
  if (!result) return c.json({ error: "Student not found" }, 404);
  return c.json({ message: "Student deleted successfully from D1", student: result });
});

/* =========================================================
   DURABLE OBJECT
   TEST SQLITE
========================================================= */

app.get(
  "/do/test",

  async (c) => {

    const studentDO =
      getStudentDO(c);

    const tables =
      await studentDO.testDatabase();

    const count =
      await studentDO.countStudents();

    return c.json({

      message:
        "Durable Object SQLite is working",

      tables,

      studentCount:
        count

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   CREATE
========================================================= */

app.post(
  "/do/student/create",
  requireDocTypePermission("Student", "create"),

  zValidator(
    "json",
    StudentCreateSchema
  ),

  async (c) => {

    const body =
      c.req.valid("json");

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.createStudent(

        body.name,

        body.age,

        body.course,

        body.marks

      );

    return c.json({

      message:
        "Student created in Durable Object SQLite",

      student

    }, 201);

  }
);

/* =========================================================
   DURABLE OBJECT
   READ ALL
========================================================= */

app.get(
  "/do/student/all",
  requireDocTypePermission("Student", "read"),

  async (c) => {

    const studentDO =
      getStudentDO(c);

    const result =
      await studentDO.getAllStudents();

    return c.json({

      count:
        result.length,

      students:
        result

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   READ ONE
========================================================= */

app.get(
  "/do/student/:id",
  requireDocTypePermission("Student", "read"),

  async (c) => {

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.getStudent(id);

    if (!student) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json(
      student
    );

  }
);

/* =========================================================
   DURABLE OBJECT
   UPDATE
========================================================= */

app.put(
  "/do/student/update/:id",
  requireDocTypePermission("Student", "update"),

  zValidator(
    "json",
    StudentUpdateSchema
  ),

  async (c) => {

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const body =
      c.req.valid("json");

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.updateStudent(
        id,
        body
      );

    if (!student) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json({

      message:
        "Student updated in Durable Object SQLite",

      student

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   DELETE
========================================================= */

app.delete(
  "/do/student/delete/:id",
  requireDocTypePermission("Student", "delete"),

  async (c) => {

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.deleteStudent(
        id
      );

    if (!student) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json({

      message:
        "Student deleted from Durable Object SQLite",

      student

    });

  }
);
app.get(
  "/rbac/business-action/check",
  authenticate,
  async (c) => {
    const authenticatedUser = await requireAuthenticatedUser(c);

    if (authenticatedUser instanceof Response) {
      return authenticatedUser;
    }

    const userId = authenticatedUser.id;
    const actionCode = c.req.query("action");
    const doctypeName = c.req.query("doctype");
    const recordIdParam = c.req.query("record_id");

    if (!actionCode) {
      return c.json(
        {
          success: false,
          message: "action is required",
        },
        400,
      );
    }

    /*
     * Without a target document, only evaluate
     * business-action + DocType permissions.
     */
    if (!doctypeName || !recordIdParam) {
      const result =
        await authorizeBusinessAction(
          c.env.DB,
          userId,
          actionCode,
        );

      return c.json({
        success: true,
        authorization: result,
      });
    }

    const recordId = Number(recordIdParam);

    if (!Number.isInteger(recordId)) {
      return c.json(
        {
          success: false,
          message: "Invalid record_id",
        },
        400,
      );
    }

    /*
     * Full authorization:
     *
     * Business Action
     * + DocType permissions
     * + Scope
     * + Target record
     */
    const result =
      await authorizeBusinessActionOnRecord(
        c.env.DB,
        userId,
        actionCode,
        doctypeName,
        recordId,
      );

    return c.json({
      success: true,
      authorization: result,
    });
  },
);
// ============================================================
// ATTENDANCE WORKFLOW
// ============================================================

app.post(
  "/attendance/:id/mark",
  authenticate,
  async (c) => {
    const id = Number(
      c.req.param("id"),
    );

    if (!Number.isInteger(id)) {
      return c.json(
        {
          success: false,
          message: "Invalid attendance id",
        },
        400,
      );
    }

    const authenticatedUser = await requireAuthenticatedUser(c);

    if (authenticatedUser instanceof Response) {
      return authenticatedUser;
    }

    const userId = authenticatedUser.id;

    const authorization =
      await authorizeBusinessActionOnRecord(
        c.env.DB,
        userId,
        "mark_attendance",
        "Attendance",
        id,
      );

    if (!authorization.allowed) {
      return c.json(
        {
          success: false,
          message: "Attendance marking denied",
          authorization,
        },
        403,
      );
    }

    const workflow =
      await executeWorkflowTransition(
        c.env.DB,
        "Attendance",
        id,
        "mark_attendance",
      );

    if (!workflow.allowed) {
      return c.json(
        {
          success: false,
          message: "Workflow transition denied",
          workflow,
        },
        409,
      );
    }

    return c.json({
      success: true,
      message: "Attendance marked",
      attendance_id: id,
      workflow,
    });
  },
);


app.post(
  "/attendance/:id/submit",
  authenticate,
  async (c) => {
    const id = Number(
      c.req.param("id"),
    );

    if (!Number.isInteger(id)) {
      return c.json(
        {
          success: false,
          message: "Invalid attendance id",
        },
        400,
      );
    }

    const authenticatedUser = await requireAuthenticatedUser(c);

    if (authenticatedUser instanceof Response) {
      return authenticatedUser;
    }

    const userId = authenticatedUser.id;

    const authorization =
      await authorizeBusinessActionOnRecord(
        c.env.DB,
        userId,
        "submit_attendance",
        "Attendance",
        id,
      );

    if (!authorization.allowed) {
      return c.json(
        {
          success: false,
          message: "Attendance submission denied",
          authorization,
        },
        403,
      );
    }

    const workflow =
      await executeWorkflowTransition(
        c.env.DB,
        "Attendance",
        id,
        "submit_attendance",
      );

    if (!workflow.allowed) {
      return c.json(
        {
          success: false,
          message: "Workflow transition denied",
          workflow,
        },
        409,
      );
    }

    return c.json({
      success: true,
      message: "Attendance submitted",
      attendance_id: id,
      workflow,
    });
  },
);


app.post(
  "/attendance/:id/approve",
  authenticate,
  async (c) => {
    const id = Number(
      c.req.param("id"),
    );

    if (!Number.isInteger(id)) {
      return c.json(
        {
          success: false,
          message: "Invalid attendance id",
        },
        400,
      );
    }

    const authenticatedUser = await requireAuthenticatedUser(c);

    if (authenticatedUser instanceof Response) {
      return authenticatedUser;
    }

    const userId = authenticatedUser.id;

    const authorization =
      await authorizeBusinessActionOnRecord(
        c.env.DB,
        userId,
        "approve_attendance",
        "Attendance",
        id,
      );

    if (!authorization.allowed) {
      return c.json(
        {
          success: false,
          message: "Attendance approval denied",
          authorization,
        },
        403,
      );
    }

    const workflow =
      await executeWorkflowTransition(
        c.env.DB,
        "Attendance",
        id,
        "approve_attendance",
      );

    if (!workflow.allowed) {
      return c.json(
        {
          success: false,
          message: "Workflow transition denied",
          workflow,
        },
        409,
      );
    }

    return c.json({
      success: true,
      message: "Attendance approved",
      attendance_id: id,
      workflow,
    });
  },
);


app.post(
  "/attendance/:id/reject",
  authenticate,
  async (c) => {
    const id = Number(
      c.req.param("id"),
    );

    if (!Number.isInteger(id)) {
      return c.json(
        {
          success: false,
          message: "Invalid attendance id",
        },
        400,
      );
    }

    const authenticatedUser = await requireAuthenticatedUser(c);

    if (authenticatedUser instanceof Response) {
      return authenticatedUser;
    }

    const userId = authenticatedUser.id;

    const authorization =
      await authorizeBusinessActionOnRecord(
        c.env.DB,
        userId,
        "reject_attendance",
        "Attendance",
        id,
      );

    if (!authorization.allowed) {
      return c.json(
        {
          success: false,
          message: "Attendance rejection denied",
          authorization,
        },
        403,
      );
    }

    const workflow =
      await executeWorkflowTransition(
        c.env.DB,
        "Attendance",
        id,
        "reject_attendance",
      );

    if (!workflow.allowed) {
      return c.json(
        {
          success: false,
          message: "Workflow transition denied",
          workflow,
        },
        409,
      );
    }

    return c.json({
      success: true,
      message: "Attendance rejected",
      attendance_id: id,
      workflow,
    });
  },
);

/* =========================================================
   EXPORT WORKER + DURABLE OBJECT
========================================================= */

export default app;

export {
  StudentDO
};