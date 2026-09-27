import type { D1Database } from "@cloudflare/workers-types";

export interface WorkflowState {
  id: number;
  stateCode: string;
  stateName: string;
  isInitial: number;
  isFinal: number;
}

export interface WorkflowTransition {
  id: number;
  actionCode: string;
  fromState: string;
  toState: string;
}

export interface WorkflowResult {
  allowed: boolean;
  reason: string;
  fromState?: string;
  toState?: string;
  action?: string;
}

export async function getCurrentWorkflowState(
  db: D1Database,
  doctypeName: string,
  recordId: number,
): Promise<WorkflowState | null> {
  if (doctypeName === "Attendance") {
    const row = await db
      .prepare(
        `
        SELECT
          ws.id,
          ws.state_code AS stateCode,
          ws.state_name AS stateName,
          ws.is_initial AS isInitial,
          ws.is_final AS isFinal
        FROM attendance a
        JOIN workflow_states ws
          ON ws.id = a.workflow_state_id
        JOIN doctypes d
          ON d.id = ws.doctype_id
        WHERE a.id = ?
          AND d.doctype_name = 'Attendance'
        LIMIT 1
        `,
      )
      .bind(recordId)
      .first<WorkflowState>();

    return row ?? null;
  }

  return null;
}

export async function getWorkflowTransition(
  db: D1Database,
  doctypeName: string,
  actionCode: string,
  currentState: string,
): Promise<WorkflowTransition | null> {
  const row = await db
    .prepare(
      `
      SELECT
        wt.id,
        wt.action_code AS actionCode,
        from_state.state_code AS fromState,
        to_state.state_code AS toState
      FROM workflow_transitions wt

      JOIN doctypes d
        ON d.id = wt.doctype_id

      JOIN workflow_states from_state
        ON from_state.id = wt.from_state_id

      JOIN workflow_states to_state
        ON to_state.id = wt.to_state_id

      WHERE d.doctype_name = ?
        AND wt.action_code = ?
        AND from_state.state_code = ?
        AND wt.is_active = 1

      LIMIT 1
      `,
    )
    .bind(
      doctypeName,
      actionCode,
      currentState,
    )
    .first<WorkflowTransition>();

  return row ?? null;
}

export async function validateWorkflowTransition(
  db: D1Database,
  doctypeName: string,
  recordId: number,
  actionCode: string,
): Promise<WorkflowResult> {
  const currentState =
    await getCurrentWorkflowState(
      db,
      doctypeName,
      recordId,
    );

  if (!currentState) {
    return {
      allowed: false,
      reason: "WORKFLOW_STATE_NOT_FOUND",
      action: actionCode,
    };
  }

  if (currentState.isFinal === 1) {
    return {
      allowed: false,
      reason: "DOCUMENT_ALREADY_FINAL",
      fromState: currentState.stateCode,
      action: actionCode,
    };
  }

  const transition =
    await getWorkflowTransition(
      db,
      doctypeName,
      actionCode,
      currentState.stateCode,
    );

  if (!transition) {
    return {
      allowed: false,
      reason: "INVALID_WORKFLOW_TRANSITION",
      fromState: currentState.stateCode,
      action: actionCode,
    };
  }

  return {
    allowed: true,
    reason: "WORKFLOW_TRANSITION_ALLOWED",
    fromState: transition.fromState,
    toState: transition.toState,
    action: actionCode,
  };
}

export async function executeWorkflowTransition(
  db: D1Database,
  doctypeName: string,
  recordId: number,
  actionCode: string,
): Promise<WorkflowResult> {
  const validation =
    await validateWorkflowTransition(
      db,
      doctypeName,
      recordId,
      actionCode,
    );

  if (!validation.allowed) {
    return validation;
  }

  if (
    doctypeName === "Attendance"
  ) {
    const targetState =
      await db
        .prepare(
          `
          SELECT ws.id
          FROM workflow_states ws
          JOIN doctypes d
            ON d.id = ws.doctype_id
          WHERE d.doctype_name = ?
            AND ws.state_code = ?
          LIMIT 1
          `,
        )
        .bind(
          doctypeName,
          validation.toState,
        )
        .first<{ id: number }>();

    if (!targetState) {
      return {
        allowed: false,
        reason: "TARGET_WORKFLOW_STATE_NOT_FOUND",
        action: actionCode,
      };
    }

    await db
      .prepare(
        `
        UPDATE attendance
        SET workflow_state_id = ?
        WHERE id = ?
        `,
      )
      .bind(
        targetState.id,
        recordId,
      )
      .run();

    return {
      allowed: true,
      reason: "WORKFLOW_TRANSITION_EXECUTED",
      fromState: validation.fromState,
      toState: validation.toState,
      action: actionCode,
    };
  }

  return {
    allowed: false,
    reason: "UNSUPPORTED_WORKFLOW_DOCTYPE",
    action: actionCode,
  };
}