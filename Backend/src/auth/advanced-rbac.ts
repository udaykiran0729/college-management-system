import type { D1Database } from "@cloudflare/workers-types";
import type { Context, Next } from "hono";

import {
  authorizeScope,
  authorizeOwnership,
  resolveDepartmentScope,
  type ScopeCode,
} from "./scope";

import {
  getAuthenticatedUser,
  getBearerToken,
  type AuthenticatedUser,
} from "./user-auth";

export type AccessEffect = "ALLOW" | "DENY";

export interface BusinessAction {
  id: number;
  actionCode: string;
  actionName: string;
}

export interface AuthorizationContext {
  userId: number;
  roleIds: number[];
}

export interface AuthorizationResult {
  allowed: boolean;
  reason: string;
  action?: string;
  scope?: string;
}

export interface ActionRequirement {
  doctypeName: string;
  permissionName: string;
  required: number;
}

/*
 * ============================================================
 * Get business action
 * ============================================================
 */

export async function getBusinessAction(
  db: D1Database,
  actionCode: string,
): Promise<BusinessAction | null> {
  const row = await db
    .prepare(
      `
      SELECT
        id,
        action_code AS actionCode,
        action_name AS actionName
      FROM business_actions
      WHERE action_code = ?
        AND is_active = 1
      LIMIT 1
      `,
    )
    .bind(actionCode)
    .first<BusinessAction>();

  return row ?? null;
}

/*
 * ============================================================
 * Get user's active roles
 * ============================================================
 */

export async function getUserRoleIds(
  db: D1Database,
  userId: number,
): Promise<number[]> {
  const result = await db
    .prepare(
      `
      SELECT role_id
      FROM user_roles
      WHERE user_id = ?
        AND is_active = 1
      ORDER BY role_id
      `,
    )
    .bind(userId)
    .all<{ role_id: number }>();

  return (result.results ?? []).map(
    (row) => row.role_id,
  );
}

/*
 * ============================================================
 * Check business-action assignment
 *
 * Multiple roles:
 *
 * ALLOW + ALLOW -> ALLOW
 * ALLOW + DENY  -> DENY
 * DENY          -> DENY
 * no rule       -> DENY
 *
 * Explicit DENY always wins.
 * ============================================================
 */

export async function hasBusinessActionPermission(
  db: D1Database,
  roleIds: number[],
  actionCode: string,
): Promise<AuthorizationResult> {
  if (roleIds.length === 0) {
    return {
      allowed: false,
      reason: "USER_HAS_NO_ROLES",
      action: actionCode,
    };
  }

  const placeholders = roleIds
    .map(() => "?")
    .join(",");

  const result = await db
    .prepare(
      `
      SELECT
        rba.effect,
        st.scope_code AS scopeCode
      FROM role_business_actions rba
      JOIN roles r
        ON r.id = rba.role_id
      JOIN business_actions ba
        ON ba.id = rba.business_action_id
      LEFT JOIN scope_types st
        ON st.id = rba.scope_type_id
      WHERE rba.role_id IN (${placeholders})
        AND ba.action_code = ?
        AND rba.is_active = 1
        AND ba.is_active = 1
        AND r.is_active = 1
      `,
    )
    .bind(
      ...roleIds,
      actionCode,
    )
    .all<{
      effect: AccessEffect;
      scopeCode: ScopeCode | null;
    }>();

  const rules = result.results ?? [];

  if (rules.length === 0) {
    return {
      allowed: false,
      reason: "BUSINESS_ACTION_NOT_ASSIGNED",
      action: actionCode,
    };
  }

  /*
   * Explicit DENY has priority.
   */
  const denyRule = rules.find(
    (rule) => rule.effect === "DENY",
  );

  if (denyRule) {
    return {
      allowed: false,
      reason: "EXPLICIT_DENY",
      action: actionCode,
      scope:
        denyRule.scopeCode ?? undefined,
    };
  }

  /*
   * At least one ALLOW is required.
   */
  const allowRule = rules.find(
    (rule) => rule.effect === "ALLOW",
  );

  if (!allowRule) {
    return {
      allowed: false,
      reason: "NO_ALLOW_RULE",
      action: actionCode,
    };
  }

  return {
    allowed: true,
    reason: "BUSINESS_ACTION_ALLOWED",
    action: actionCode,
    scope:
      allowRule.scopeCode ?? undefined,
  };
}

/*
 * ============================================================
 * Get DocType requirements
 * ============================================================
 */

export async function getBusinessActionRequirements(
  db: D1Database,
  actionCode: string,
): Promise<ActionRequirement[]> {
  const result = await db
    .prepare(
      `
      SELECT
        d.doctype_name AS doctypeName,
        p.action_name AS permissionName,
        bar.required
      FROM business_action_requirements bar
      JOIN business_actions ba
        ON ba.id = bar.business_action_id
      JOIN doctypes d
        ON d.id = bar.doctype_id
      JOIN permissions p
        ON p.id = bar.permission_id
      WHERE ba.action_code = ?
        AND ba.is_active = 1
        AND d.is_active = 1
      ORDER BY bar.id
      `,
    )
    .bind(actionCode)
    .all<ActionRequirement>();

  return result.results ?? [];
}

/*
 * ============================================================
 * Check atomic DocType permission
 *
 * Explicit DENY always wins.
 * ============================================================
 */

export async function hasAtomicPermission(
  db: D1Database,
  roleIds: number[],
  doctypeName: string,
  permissionName: string,
): Promise<boolean> {
  if (roleIds.length === 0) {
    return false;
  }

  const placeholders = roleIds
    .map(() => "?")
    .join(",");

  const result = await db
    .prepare(
      `
      SELECT
        drp.effect
      FROM doctype_role_permissions drp
      JOIN roles r
        ON r.id = drp.role_id
      JOIN doctypes d
        ON d.id = drp.doctype_id
      JOIN permissions p
        ON p.id = drp.permission_id
      WHERE drp.role_id IN (${placeholders})
        AND d.doctype_name = ?
        AND p.action_name = ?
        AND drp.is_active = 1
        AND r.is_active = 1
      `,
    )
    .bind(
      ...roleIds,
      doctypeName,
      permissionName,
    )
    .all<{
      effect: AccessEffect;
    }>();

  const rules = result.results ?? [];

  /*
   * DENY overrides ALLOW.
   */
  if (
    rules.some(
      (rule) => rule.effect === "DENY",
    )
  ) {
    return false;
  }

  return rules.some(
    (rule) => rule.effect === "ALLOW",
  );
}

/*
 * ============================================================
 * Authorize business action
 *
 * User
 *   ↓
 * Roles
 *   ↓
 * Business Action
 *   ↓
 * Required DocTypes
 *   ↓
 * Required permissions
 * ============================================================
 */

export async function authorizeBusinessAction(
  db: D1Database,
  userId: number,
  actionCode: string,
): Promise<AuthorizationResult> {
  /*
   * STEP 1
   * Get user's active roles.
   */

  const roleIds =
    await getUserRoleIds(
      db,
      userId,
    );

  if (roleIds.length === 0) {
    return {
      allowed: false,
      reason: "USER_HAS_NO_ROLES",
      action: actionCode,
    };
  }

  /*
   * STEP 2
   * Check business-action assignment.
   */

  const actionResult =
    await hasBusinessActionPermission(
      db,
      roleIds,
      actionCode,
    );

  if (!actionResult.allowed) {
    return actionResult;
  }

  /*
   * STEP 3
   * Find required DocType permissions.
   */

  const requirements =
    await getBusinessActionRequirements(
      db,
      actionCode,
    );

  if (requirements.length === 0) {
    return {
      allowed: false,
      reason: "ACTION_HAS_NO_REQUIREMENTS",
      action: actionCode,
      scope: actionResult.scope,
    };
  }

  /*
   * STEP 4
   * Every required permission must pass.
   */

  for (const requirement of requirements) {
    const allowed =
      await hasAtomicPermission(
        db,
        roleIds,
        requirement.doctypeName,
        requirement.permissionName,
      );

    if (
      !allowed &&
      requirement.required === 1
    ) {
      return {
        allowed: false,
        reason:
          `MISSING_PERMISSION:${requirement.doctypeName}:${requirement.permissionName}`,
        action: actionCode,
        scope: actionResult.scope,
      };
    }
  }

  return {
    allowed: true,
    reason: "BUSINESS_ACTION_AUTHORIZED",
    action: actionCode,
    scope: actionResult.scope,
  };
}

/*
 * ============================================================
 * Authorize business action against a specific record
 *
 * SYSTEM
 *   → bypass record scope
 *
 * OWN
 *   → verify actual ownership
 *
 * DEPARTMENT
 *   → resolve target department
 *   → compare user's department scope
 * ============================================================
 */

export async function authorizeBusinessActionOnRecord(
  db: D1Database,
  userId: number,
  actionCode: string,
  targetDocType: string,
  targetRecordId: number,
): Promise<AuthorizationResult> {
  /*
   * STEP 1
   * Business-action + atomic permissions.
   */

  const actionResult =
    await authorizeBusinessAction(
      db,
      userId,
      actionCode,
    );

  if (!actionResult.allowed) {
    return actionResult;
  }

  /*
   * STEP 2
   * SYSTEM scope.
   */

  if (actionResult.scope === "SYSTEM") {
    return {
      allowed: true,
      reason: "SYSTEM_SCOPE_AUTHORIZED",
      action: actionCode,
      scope: "SYSTEM",
    };
  }

  /*
   * STEP 3
   * OWN scope.
   */

  if (actionResult.scope === "OWN") {
    const ownership =
      await authorizeOwnership(
        db,
        userId,
        targetDocType,
        targetRecordId,
      );

    if (!ownership.allowed) {
      return {
        allowed: false,
        reason: ownership.reason,
        action: actionCode,
        scope: "OWN",
      };
    }

    return {
      allowed: true,
      reason:
        "BUSINESS_ACTION_AND_OWNERSHIP_AUTHORIZED",
      action: actionCode,
      scope: "OWN",
    };
  }

  /*
   * STEP 4
   * Resolve target department.
   *
   * Current scoped actions use DEPARTMENT.
   */

  const targetDepartmentId =
    await resolveDepartmentScope(
      db,
      targetDocType,
      targetRecordId,
    );

  if (targetDepartmentId === null) {
    return {
      allowed: false,
      reason: "TARGET_SCOPE_NOT_FOUND",
      action: actionCode,
      scope: actionResult.scope,
    };
  }

  /*
   * STEP 5
   * Compare user's scope with target scope.
   */

  const scopeResult =
    await authorizeScope(
      db,
      userId,
      actionResult.scope as ScopeCode,
      targetDepartmentId,
    );

  if (!scopeResult.allowed) {
    return {
      allowed: false,
      reason: scopeResult.reason,
      action: actionCode,
      scope: actionResult.scope,
    };
  }

  return {
    allowed: true,
    reason:
      "BUSINESS_ACTION_AND_SCOPE_AUTHORIZED",
    action: actionCode,
    scope: actionResult.scope,
  };
}

/*
 * ============================================================
 * Hono authenticated-user context helper
 * ============================================================
 *
 * The authenticated user is stored in Hono context.
 *
 * Authentication source:
 *
 * Authorization: Bearer <token>
 *        ↓
 * user_api_tokens
 *        ↓
 * authenticated user
 *        ↓
 * user.id
 *
 * No X-User-Id header is trusted.
 * ============================================================
 */

export function getAuthenticatedContextUser(
  c: Context,
): AuthenticatedUser | undefined {
  return c.get(
    "authenticatedUser" as never,
  ) as AuthenticatedUser | undefined;
}

/*
 * ============================================================
 * Hono middleware
 * ============================================================
 */

export function requireBusinessAction(
  actionCode: string,
  options?: {
    doctype?: string;
    recordIdFromQuery?: string;
  },
) {
  return async (
    c: Context,
    next: Next,
  ) => {
    const authorizationHeader =
      c.req.header("Authorization");

    const token =
      getBearerToken(
        authorizationHeader,
      );

    if (!token) {
      return c.json(
        {
          success: false,
          message:
            "Bearer token is required",
        },
        401,
      );
    }

    const authenticatedUser =
      await getAuthenticatedUser(
        c.env.DB,
        token,
      );

    if (!authenticatedUser) {
      return c.json(
        {
          success: false,
          message:
            "Invalid or expired authentication token",
        },
        401,
      );
    }

    /*
     * Store authenticated identity
     * in Hono context.
     */
    c.set(
      "authenticatedUser" as never,
      authenticatedUser,
    );

    /*
     * User ID comes only from the
     * database-backed bearer token.
     */
    const userId =
      authenticatedUser.id;

    const doctype =
      options?.doctype ??
      c.req.query("doctype");

    const recordIdValue =
      options?.recordIdFromQuery
        ? c.req.query(
            options.recordIdFromQuery,
          )
        : c.req.query("record_id");

    let result: AuthorizationResult;

    /*
     * Record-level authorization.
     */

    if (
      doctype &&
      recordIdValue
    ) {
      const recordId =
        Number(recordIdValue);

      if (!Number.isInteger(recordId)) {
        return c.json(
          {
            success: false,
            message:
              "Invalid record_id",
          },
          400,
        );
      }

      result =
        await authorizeBusinessActionOnRecord(
          c.env.DB,
          userId,
          actionCode,
          doctype,
          recordId,
        );
    } else {
      /*
       * Action-level authorization.
       */

      result =
        await authorizeBusinessAction(
          c.env.DB,
          userId,
          actionCode,
        );
    }

    if (!result.allowed) {
      return c.json(
        {
          success: false,
          message:
            "Business action denied",
          authorization: result,
        },
        403,
      );
    }

    /*
     * Expose authorization information
     * for API inspection/debugging.
     */

    c.header(
      "X-RBAC-Action",
      actionCode,
    );

    c.header(
      "X-RBAC-Scope",
      result.scope ?? "NONE",
    );

    c.header(
      "X-RBAC-User-Id",
      String(userId),
    );

    await next();
  };
}