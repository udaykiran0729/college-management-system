-- ============================================================
-- 0014: Attendance workflow business actions
-- ============================================================

INSERT INTO business_actions (
  action_code,
  action_name,
  description,
  is_active
)
VALUES
(
  'submit_attendance',
  'Submit Attendance',
  'Submit marked attendance for approval',
  1
),
(
  'reject_attendance',
  'Reject Attendance',
  'Reject submitted attendance',
  1
)
ON CONFLICT(action_code) DO NOTHING;


-- ------------------------------------------------------------
-- Attendance DocType requirements
-- ------------------------------------------------------------

INSERT INTO business_action_requirements (
  business_action_id,
  doctype_id,
  permission_id,
  required
)
SELECT
  ba.id,
  d.id,
  p.id,
  1
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Attendance'
JOIN permissions p
  ON p.action_name = 'update'
WHERE ba.action_code = 'submit_attendance'
ON CONFLICT DO NOTHING;


INSERT INTO business_action_requirements (
  business_action_id,
  doctype_id,
  permission_id,
  required
)
SELECT
  ba.id,
  d.id,
  p.id,
  1
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Attendance'
JOIN permissions p
  ON p.action_name = 'update'
WHERE ba.action_code = 'reject_attendance'
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- Faculty can submit attendance
-- ------------------------------------------------------------

INSERT INTO role_business_actions (
  role_id,
  business_action_id,
  scope_type_id,
  effect,
  is_active
)
SELECT
  r.id,
  ba.id,
  st.id,
  'ALLOW',
  1
FROM roles r
JOIN business_actions ba
  ON ba.action_code = 'submit_attendance'
JOIN scope_types st
  ON st.scope_code = 'DEPARTMENT'
WHERE r.role_name = 'FACULTY'
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- HOD can reject attendance
-- ------------------------------------------------------------

INSERT INTO role_business_actions (
  role_id,
  business_action_id,
  scope_type_id,
  effect,
  is_active
)
SELECT
  r.id,
  ba.id,
  st.id,
  'ALLOW',
  1
FROM roles r
JOIN business_actions ba
  ON ba.action_code = 'reject_attendance'
JOIN scope_types st
  ON st.scope_code = 'DEPARTMENT'
WHERE r.role_name = 'HOD'
ON CONFLICT DO NOTHING;