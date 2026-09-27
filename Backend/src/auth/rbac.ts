import type { Context, Next } from "hono";

export const ROLE_NAMES = [
  "SUPER_ADMIN",
  "ADMIN",
  "HOD",
  "FACULTY",
  "STUDENT",
] as const;

export type Role = (typeof ROLE_NAMES)[number];

export const PERMISSIONS = [
  "create",
  "read",
  "update",
  "delete",
] as const;

export type Permission = (typeof PERMISSIONS)[number];

export const DOCTYPES = [
  "Branch",
  "Department",
  "Course",
  "Student",
  "Faculty",
  "Subject",
  "Enrollment",
  "Attendance",
  "User",
  "Role",
  "Role Permission",
] as const;

export type DocType = (typeof DOCTYPES)[number];

export type PermissionScope =
  | "ALL"
  | "BRANCH"
  | "DEPARTMENT"
  | "OWN";

type RoleTokenEnv = {
  API_TOKEN: string;
  ADMIN_TOKEN?: string;
  HOD_TOKEN?: string;
  FACULTY_TOKEN?: string;
  STUDENT_TOKEN?: string;
};

export function getRoleFromToken(
  token: string,
  env: RoleTokenEnv,
): Role | null {
  if (token === env.API_TOKEN) {
    return "SUPER_ADMIN";
  }

  if (env.ADMIN_TOKEN && token === env.ADMIN_TOKEN) {
    return "ADMIN";
  }

  if (env.HOD_TOKEN && token === env.HOD_TOKEN) {
    return "HOD";
  }

  if (env.FACULTY_TOKEN && token === env.FACULTY_TOKEN) {
    return "FACULTY";
  }

  if (env.STUDENT_TOKEN && token === env.STUDENT_TOKEN) {
    return "STUDENT";
  }

  return null;
}

/**
 * Database-driven DocType authorization.
 *
 * Authorization flow:
 *
 * Role
 *   ↓
 * DocType
 *   ↓
 * Permission
 *   ↓
 * Scope
 */
export async function hasDocTypePermission(
  db: D1Database,
  role: Role,
  doctype: DocType,
  permission: Permission,
): Promise<boolean> {
  const result = await db
    .prepare(
      `
      SELECT 1
      FROM doctype_role_permissions drp

      JOIN roles r
        ON r.id = drp.role_id

      JOIN doctypes d
        ON d.id = drp.doctype_id

      JOIN permissions p
        ON p.id = drp.permission_id

      WHERE r.role_name = ?
        AND d.doctype_name = ?
        AND p.action_name = ?
        AND r.is_active = 1
        AND d.is_active = 1
        AND drp.is_active = 1

      LIMIT 1
      `,
    )
    .bind(role, doctype, permission)
    .first();

  return result !== null;
}

/**
 * Returns the scope assigned to a role for a DocType/action.
 */
export async function getDocTypePermissionScope(
  db: D1Database,
  role: Role,
  doctype: DocType,
  permission: Permission,
): Promise<PermissionScope | null> {
  const result = await db
    .prepare(
      `
      SELECT drp.scope
      FROM doctype_role_permissions drp

      JOIN roles r
        ON r.id = drp.role_id

      JOIN doctypes d
        ON d.id = drp.doctype_id

      JOIN permissions p
        ON p.id = drp.permission_id

      WHERE r.role_name = ?
        AND d.doctype_name = ?
        AND p.action_name = ?
        AND r.is_active = 1
        AND d.is_active = 1
        AND drp.is_active = 1

      LIMIT 1
      `,
    )
    .bind(role, doctype, permission)
    .first<{ scope: string }>();

  if (!result) {
    return null;
  }

  if (
    result.scope === "ALL" ||
    result.scope === "BRANCH" ||
    result.scope === "DEPARTMENT" ||
    result.scope === "OWN"
  ) {
    return result.scope;
  }

  return null;
}

/**
 * Generic Hono authorization middleware.
 *
 * Example:
 *
 * requireDocTypePermission("Student", "read")
 */
export function requireDocTypePermission(
  doctype: DocType,
  permission: Permission,
) {
  return async (
    c: Context<{
      Bindings: RoleTokenEnv & {
        DB: D1Database;
      };
      Variables: {
        role: Role;
      };
    }>,
    next: Next,
  ) => {
    const role = c.get("role");

    if (!role) {
      return c.json(
        {
          success: false,
          message: "Authentication required",
        },
        401,
      );
    }

    const allowed = await hasDocTypePermission(
      c.env.DB,
      role,
      doctype,
      permission,
    );

    if (!allowed) {
      return c.json(
        {
          success: false,
          message: "Permission denied",
          authorization: {
            role,
            doctype,
            permission,
          },
        },
        403,
      );
    }

    await next();
  };
}