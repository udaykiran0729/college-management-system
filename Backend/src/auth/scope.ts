import type { D1Database } from "@cloudflare/workers-types";

export type ScopeCode =
  | "SYSTEM"
  | "BRANCH"
  | "DEPARTMENT"
  | "COURSE"
  | "OWN";

export interface ScopeRule {
  scopeCode: ScopeCode;
  scopeId: number | null;
}

export async function getUserScopes(
  db: D1Database,
  userId: number,
): Promise<ScopeRule[]> {
  const result = await db
    .prepare(
      `
      SELECT
        st.scope_code AS scopeCode,
        usr.scope_id AS scopeId
      FROM user_scope_rules usr
      JOIN scope_types st
        ON st.id = usr.scope_type_id
      WHERE usr.user_id = ?
        AND usr.is_active = 1
        AND st.is_active = 1
      ORDER BY usr.id
      `,
    )
    .bind(userId)
    .all<ScopeRule>();

  return result.results ?? [];
}

export async function hasSystemScope(
  db: D1Database,
  userId: number,
): Promise<boolean> {
  const result = await db
    .prepare(
      `
      SELECT 1
      FROM user_scope_rules usr
      JOIN scope_types st
        ON st.id = usr.scope_type_id
      WHERE usr.user_id = ?
        AND st.scope_code = 'SYSTEM'
        AND usr.is_active = 1
        AND st.is_active = 1
      LIMIT 1
      `,
    )
    .bind(userId)
    .first();

  return Boolean(result);
}

export async function getUserAccessModes(
  db: D1Database,
  userId: number,
): Promise<string[]> {
  const result = await db
    .prepare(
      `
      SELECT DISTINCT
        r.access_mode AS accessMode
      FROM user_roles ur
      JOIN roles r
        ON r.id = ur.role_id
      WHERE ur.user_id = ?
        AND ur.is_active = 1
        AND r.is_active = 1
      `,
    )
    .bind(userId)
    .all<{ accessMode: string }>();

  return (result.results ?? []).map(
    (row) => row.accessMode,
  );
}

export async function getUserStudentId(
  db: D1Database,
  userId: number,
): Promise<number | null> {
  const row = await db
    .prepare(
      `
      SELECT student_id
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
    )
    .bind(userId)
    .first<{ student_id: number | null }>();

  return row?.student_id ?? null;
}

export async function resolveOwnerStudentId(
  db: D1Database,
  doctypeName: string,
  recordId: number,
): Promise<number | null> {
  switch (doctypeName) {
    case "Student": {
      const row = await db
        .prepare(
          `
          SELECT id
          FROM students
          WHERE id = ?
          LIMIT 1
          `,
        )
        .bind(recordId)
        .first<{ id: number }>();

      return row?.id ?? null;
    }

    case "Enrollment": {
      const row = await db
        .prepare(
          `
          SELECT student_id
          FROM enrollments
          WHERE id = ?
          LIMIT 1
          `,
        )
        .bind(recordId)
        .first<{ student_id: number }>();

      return row?.student_id ?? null;
    }

    case "Attendance": {
      const row = await db
        .prepare(
          `
          SELECT e.student_id
          FROM attendance a
          JOIN enrollments e
            ON e.id = a.enrollment_id
          WHERE a.id = ?
          LIMIT 1
          `,
        )
        .bind(recordId)
        .first<{ student_id: number }>();

      return row?.student_id ?? null;
    }

    default:
      return null;
  }
}

export async function authorizeOwnership(
  db: D1Database,
  userId: number,
  doctypeName: string,
  recordId: number,
): Promise<{
  allowed: boolean;
  reason: string;
  userStudentId?: number | null;
  ownerStudentId?: number | null;
}> {
  const userStudentId =
    await getUserStudentId(
      db,
      userId,
    );

  if (userStudentId === null) {
    return {
      allowed: false,
      reason: "USER_NOT_LINKED_TO_STUDENT",
      userStudentId,
    };
  }

  const ownerStudentId =
    await resolveOwnerStudentId(
      db,
      doctypeName,
      recordId,
    );

  if (ownerStudentId === null) {
    return {
      allowed: false,
      reason: "OWNER_NOT_FOUND",
      userStudentId,
    };
  }

  if (ownerStudentId !== userStudentId) {
    return {
      allowed: false,
      reason: "OWNERSHIP_MISMATCH",
      userStudentId,
      ownerStudentId,
    };
  }

  return {
    allowed: true,
    reason: "OWNERSHIP_MATCH",
    userStudentId,
    ownerStudentId,
  };
}

export async function authorizeScope(
  db: D1Database,
  userId: number,
  requiredScope: ScopeCode,
  targetScopeId?: number | null,
): Promise<{
  allowed: boolean;
  reason: string;
}> {
  const accessModes =
    await getUserAccessModes(
      db,
      userId,
    );

  if (accessModes.includes("SYSTEM")) {
    return {
      allowed: true,
      reason: "SYSTEM_SCOPE",
    };
  }

  if (requiredScope === "OWN") {
    return {
      allowed: true,
      reason: "OWN_SCOPE_REQUIRES_OWNER_CHECK",
    };
  }

  if (
    targetScopeId === undefined ||
    targetScopeId === null
  ) {
    return {
      allowed: false,
      reason: "TARGET_SCOPE_NOT_PROVIDED",
    };
  }

  const result = await db
    .prepare(
      `
      SELECT 1
      FROM user_scope_rules usr
      JOIN scope_types st
        ON st.id = usr.scope_type_id
      WHERE usr.user_id = ?
        AND st.scope_code = ?
        AND usr.scope_id = ?
        AND usr.is_active = 1
        AND st.is_active = 1
      LIMIT 1
      `,
    )
    .bind(
      userId,
      requiredScope,
      targetScopeId,
    )
    .first();

  if (!result) {
    return {
      allowed: false,
      reason: "SCOPE_MISMATCH",
    };
  }

  return {
    allowed: true,
    reason: "SCOPE_MATCH",
  };
}

export async function resolveDepartmentScope(
  db: D1Database,
  doctypeName: string,
  recordId: number,
): Promise<number | null> {
  switch (doctypeName) {
    case "Department": {
      const row = await db
        .prepare(
          `
          SELECT id
          FROM departments
          WHERE id = ?
          `,
        )
        .bind(recordId)
        .first<{ id: number }>();

      return row?.id ?? null;
    }

    case "Faculty": {
      const row = await db
        .prepare(
          `
          SELECT department_id
          FROM faculty
          WHERE id = ?
          `,
        )
        .bind(recordId)
        .first<{ department_id: number }>();

      return row?.department_id ?? null;
    }

    case "Course": {
      const row = await db
        .prepare(
          `
          SELECT department_id
          FROM courses
          WHERE id = ?
          `,
        )
        .bind(recordId)
        .first<{ department_id: number }>();

      return row?.department_id ?? null;
    }

    case "Subject": {
      const row = await db
        .prepare(
          `
          SELECT c.department_id
          FROM subjects s
          JOIN courses c
            ON c.id = s.course_id
          WHERE s.id = ?
          `,
        )
        .bind(recordId)
        .first<{ department_id: number }>();

      return row?.department_id ?? null;
    }

    case "Enrollment": {
      const row = await db
        .prepare(
          `
          SELECT c.department_id
          FROM enrollments e
          JOIN courses c
            ON c.id = e.course_id
          WHERE e.id = ?
          `,
        )
        .bind(recordId)
        .first<{ department_id: number }>();

      return row?.department_id ?? null;
    }

    case "Attendance": {
      const row = await db
        .prepare(
          `
          SELECT c.department_id
          FROM attendance a
          JOIN enrollments e
            ON e.id = a.enrollment_id
          JOIN courses c
            ON c.id = e.course_id
          WHERE a.id = ?
          `,
        )
        .bind(recordId)
        .first<{ department_id: number }>();

      return row?.department_id ?? null;
    }

    default:
      return null;
  }
}