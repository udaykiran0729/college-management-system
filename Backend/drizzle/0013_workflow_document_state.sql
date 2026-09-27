-- ============================================================
-- 0013: Document workflow state
-- ============================================================

ALTER TABLE attendance
ADD COLUMN workflow_state_id INTEGER;

-- Existing attendance records start in MARKED state.
UPDATE attendance
SET workflow_state_id = (
  SELECT ws.id
  FROM workflow_states ws
  JOIN doctypes d
    ON d.id = ws.doctype_id
  WHERE d.doctype_name = 'Attendance'
    AND ws.state_code = 'MARKED'
  LIMIT 1
)
WHERE workflow_state_id IS NULL;