-- ============================================================
-- 0012: Workflow foundation
-- ============================================================

CREATE TABLE IF NOT EXISTS workflow_states (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  doctype_id INTEGER NOT NULL,
  state_code TEXT NOT NULL,
  state_name TEXT NOT NULL,

  is_initial INTEGER NOT NULL DEFAULT 0,
  is_final INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (doctype_id, state_code),

  FOREIGN KEY (doctype_id)
    REFERENCES doctypes(id)
);


CREATE TABLE IF NOT EXISTS workflow_transitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  doctype_id INTEGER NOT NULL,

  action_code TEXT NOT NULL,

  from_state_id INTEGER NOT NULL,
  to_state_id INTEGER NOT NULL,

  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (
    doctype_id,
    action_code,
    from_state_id
  ),

  FOREIGN KEY (doctype_id)
    REFERENCES doctypes(id),

  FOREIGN KEY (from_state_id)
    REFERENCES workflow_states(id),

  FOREIGN KEY (to_state_id)
    REFERENCES workflow_states(id)
);


-- ------------------------------------------------------------
-- Attendance workflow states
-- ------------------------------------------------------------

INSERT INTO workflow_states
  (
    doctype_id,
    state_code,
    state_name,
    is_initial,
    is_final
  )
SELECT
  d.id,
  'PENDING',
  'Pending',
  1,
  0
FROM doctypes d
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(doctype_id, state_code) DO NOTHING;


INSERT INTO workflow_states
  (
    doctype_id,
    state_code,
    state_name,
    is_initial,
    is_final
  )
SELECT
  d.id,
  'MARKED',
  'Marked',
  0,
  0
FROM doctypes d
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(doctype_id, state_code) DO NOTHING;


INSERT INTO workflow_states
  (
    doctype_id,
    state_code,
    state_name,
    is_initial,
    is_final
  )
SELECT
  d.id,
  'SUBMITTED',
  'Submitted',
  0,
  0
FROM doctypes d
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(doctype_id, state_code) DO NOTHING;


INSERT INTO workflow_states
  (
    doctype_id,
    state_code,
    state_name,
    is_initial,
    is_final
  )
SELECT
  d.id,
  'APPROVED',
  'Approved',
  0,
  1
FROM doctypes d
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(doctype_id, state_code) DO NOTHING;


INSERT INTO workflow_states
  (
    doctype_id,
    state_code,
    state_name,
    is_initial,
    is_final
  )
SELECT
  d.id,
  'REJECTED',
  'Rejected',
  0,
  1
FROM doctypes d
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(doctype_id, state_code) DO NOTHING;


-- ------------------------------------------------------------
-- Attendance workflow transitions
-- ------------------------------------------------------------

INSERT INTO workflow_transitions
  (
    doctype_id,
    action_code,
    from_state_id,
    to_state_id
  )
SELECT
  d.id,
  'mark_attendance',
  s1.id,
  s2.id
FROM doctypes d
JOIN workflow_states s1
  ON s1.doctype_id = d.id
 AND s1.state_code = 'PENDING'
JOIN workflow_states s2
  ON s2.doctype_id = d.id
 AND s2.state_code = 'MARKED'
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(
  doctype_id,
  action_code,
  from_state_id
) DO NOTHING;


INSERT INTO workflow_transitions
  (
    doctype_id,
    action_code,
    from_state_id,
    to_state_id
  )
SELECT
  d.id,
  'submit_attendance',
  s1.id,
  s2.id
FROM doctypes d
JOIN workflow_states s1
  ON s1.doctype_id = d.id
 AND s1.state_code = 'MARKED'
JOIN workflow_states s2
  ON s2.doctype_id = d.id
 AND s2.state_code = 'SUBMITTED'
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(
  doctype_id,
  action_code,
  from_state_id
) DO NOTHING;


INSERT INTO workflow_transitions
  (
    doctype_id,
    action_code,
    from_state_id,
    to_state_id
  )
SELECT
  d.id,
  'approve_attendance',
  s1.id,
  s2.id
FROM doctypes d
JOIN workflow_states s1
  ON s1.doctype_id = d.id
 AND s1.state_code = 'SUBMITTED'
JOIN workflow_states s2
  ON s2.doctype_id = d.id
 AND s2.state_code = 'APPROVED'
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(
  doctype_id,
  action_code,
  from_state_id
) DO NOTHING;


INSERT INTO workflow_transitions
  (
    doctype_id,
    action_code,
    from_state_id,
    to_state_id
  )
SELECT
  d.id,
  'reject_attendance',
  s1.id,
  s2.id
FROM doctypes d
JOIN workflow_states s1
  ON s1.doctype_id = d.id
 AND s1.state_code = 'SUBMITTED'
JOIN workflow_states s2
  ON s2.doctype_id = d.id
 AND s2.state_code = 'REJECTED'
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(
  doctype_id,
  action_code,
  from_state_id
) DO NOTHING;