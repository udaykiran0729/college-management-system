-- ============================================================
-- 0011: Advanced ERP-style RBAC foundation
-- ============================================================

-- ------------------------------------------------------------
-- 1. Multiple roles per user
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS user_roles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  user_id INTEGER NOT NULL,
  role_id INTEGER NOT NULL,

  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (user_id, role_id),

  FOREIGN KEY (user_id)
    REFERENCES users(id),

  FOREIGN KEY (role_id)
    REFERENCES roles(id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user
  ON user_roles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_role
  ON user_roles(role_id);


-- ------------------------------------------------------------
-- 2. Role access mode
--
-- SYSTEM = system-wide access
-- SCOPED = restricted to assigned organizational scope
-- OWN    = user can operate only on own records
-- ------------------------------------------------------------

ALTER TABLE roles
ADD COLUMN access_mode TEXT NOT NULL DEFAULT 'SCOPED';


-- ------------------------------------------------------------
-- 3. Explicit ALLOW / DENY for atomic permissions
-- ------------------------------------------------------------

ALTER TABLE doctype_role_permissions
ADD COLUMN effect TEXT NOT NULL DEFAULT 'ALLOW';


-- ------------------------------------------------------------
-- 4. Scope types
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS scope_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  scope_code TEXT NOT NULL UNIQUE,
  scope_name TEXT NOT NULL,
  description TEXT,

  is_active INTEGER NOT NULL DEFAULT 1
);


INSERT INTO scope_types
  (scope_code, scope_name, description)
VALUES
  (
    'SYSTEM',
    'System',
    'Access across the complete system'
  ),
  (
    'BRANCH',
    'Branch',
    'Access restricted to an academic branch'
  ),
  (
    'DEPARTMENT',
    'Department',
    'Access restricted to an academic department'
  ),
  (
    'COURSE',
    'Course',
    'Access restricted to an academic course'
  ),
  (
    'OWN',
    'Own',
    'Access restricted to records owned by the current user'
  )
ON CONFLICT(scope_code) DO NOTHING;


-- ------------------------------------------------------------
-- 5. DocType scope mapping
--
-- resolution_key is interpreted by application code.
-- It is intentionally stored as metadata instead of allowing
-- arbitrary SQL expressions.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS doctype_scope_mappings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  doctype_id INTEGER NOT NULL,
  scope_type_id INTEGER NOT NULL,

  resolution_key TEXT NOT NULL,

  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (doctype_id, scope_type_id),

  FOREIGN KEY (doctype_id)
    REFERENCES doctypes(id),

  FOREIGN KEY (scope_type_id)
    REFERENCES scope_types(id)
);


-- ------------------------------------------------------------
-- 6. Business actions
--
-- These are meaningful ERP/business operations rather than
-- simple CRUD operations.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS business_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  action_code TEXT NOT NULL UNIQUE,
  action_name TEXT NOT NULL,

  description TEXT,

  is_active INTEGER NOT NULL DEFAULT 1
);


INSERT INTO business_actions
  (action_code, action_name, description)
VALUES
  (
    'mark_attendance',
    'Mark Attendance',
    'Record attendance for students in a subject'
  ),
  (
    'approve_attendance',
    'Approve Attendance',
    'Approve submitted attendance records'
  ),
  (
    'enroll_student',
    'Enroll Student',
    'Enroll a student into a course for an academic period'
  ),
  (
    'transfer_student',
    'Transfer Student',
    'Transfer a student between academic courses or departments'
  ),
  (
    'assign_faculty',
    'Assign Faculty',
    'Assign faculty responsibility to an academic subject'
  ),
  (
    'promote_student',
    'Promote Student',
    'Promote a student to the next academic level'
  ),
  (
    'generate_student_report',
    'Generate Student Report',
    'Generate an academic report for a student'
  ),
  (
    'export_department_data',
    'Export Department Data',
    'Export academic data belonging to a department'
  )
ON CONFLICT(action_code) DO NOTHING;


-- ------------------------------------------------------------
-- 7. Business action requirements
--
-- One business action may require permissions across multiple
-- DocTypes.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS business_action_requirements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  business_action_id INTEGER NOT NULL,
  doctype_id INTEGER NOT NULL,
  permission_id INTEGER NOT NULL,

  required INTEGER NOT NULL DEFAULT 1,

  UNIQUE (
    business_action_id,
    doctype_id,
    permission_id
  ),

  FOREIGN KEY (business_action_id)
    REFERENCES business_actions(id),

  FOREIGN KEY (doctype_id)
    REFERENCES doctypes(id),

  FOREIGN KEY (permission_id)
    REFERENCES permissions(id)
);


-- ------------------------------------------------------------
-- 8. Add advanced permission definitions
-- ------------------------------------------------------------

INSERT INTO permissions
  (action_name, description)
VALUES
  (
    'mark_attendance',
    'Mark attendance'
  ),
  (
    'approve_attendance',
    'Approve attendance'
  ),
  (
    'enroll',
    'Enroll a student'
  ),
  (
    'transfer',
    'Transfer a student'
  ),
  (
    'assign_faculty',
    'Assign faculty to an academic subject'
  ),
  (
    'promote',
    'Promote a student'
  ),
  (
    'generate_report',
    'Generate an academic report'
  ),
  (
    'export',
    'Export data'
  )
ON CONFLICT(action_name) DO NOTHING;


-- ------------------------------------------------------------
-- 9. Role → Business Action
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS role_business_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  role_id INTEGER NOT NULL,
  business_action_id INTEGER NOT NULL,

  effect TEXT NOT NULL DEFAULT 'ALLOW',

  scope_type_id INTEGER,

  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (role_id, business_action_id),

  FOREIGN KEY (role_id)
    REFERENCES roles(id),

  FOREIGN KEY (business_action_id)
    REFERENCES business_actions(id),

  FOREIGN KEY (scope_type_id)
    REFERENCES scope_types(id)
);


CREATE INDEX IF NOT EXISTS idx_role_business_actions_role
  ON role_business_actions(role_id);

CREATE INDEX IF NOT EXISTS idx_role_business_actions_action
  ON role_business_actions(business_action_id);


-- ------------------------------------------------------------
-- 10. User organizational scope
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS user_scope_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  user_id INTEGER NOT NULL,
  scope_type_id INTEGER NOT NULL,

  scope_id INTEGER,

  valid_from TEXT,
  valid_to TEXT,

  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (
    user_id,
    scope_type_id,
    scope_id
  ),

  FOREIGN KEY (user_id)
    REFERENCES users(id),

  FOREIGN KEY (scope_type_id)
    REFERENCES scope_types(id)
);


CREATE INDEX IF NOT EXISTS idx_user_scope_rules_user
  ON user_scope_rules(user_id);

CREATE INDEX IF NOT EXISTS idx_user_scope_rules_scope
  ON user_scope_rules(scope_type_id, scope_id);


-- ------------------------------------------------------------
-- 11. Configure role access modes
-- ------------------------------------------------------------

UPDATE roles
SET access_mode = 'SYSTEM'
WHERE role_name IN (
  'SUPER_ADMIN',
  'ADMIN'
);

UPDATE roles
SET access_mode = 'SCOPED'
WHERE role_name IN (
  'HOD',
  'FACULTY'
);

UPDATE roles
SET access_mode = 'OWN'
WHERE role_name = 'STUDENT';


-- ------------------------------------------------------------
-- 12. Copy existing single-role assignments into user_roles
--
-- Existing users.role_id is retained for backward compatibility.
-- ------------------------------------------------------------

INSERT INTO user_roles
  (user_id, role_id, is_active)
SELECT
  id,
  role_id,
  is_active
FROM users
WHERE role_id IS NOT NULL
ON CONFLICT(user_id, role_id) DO NOTHING;


-- ============================================================
-- 13. DocType scope metadata
-- ============================================================

INSERT INTO doctype_scope_mappings
  (doctype_id, scope_type_id, resolution_key)

SELECT
  d.id,
  s.id,
  'direct.branch_id'
FROM doctypes d
JOIN scope_types s
  ON s.scope_code = 'BRANCH'
WHERE d.doctype_name = 'Branch'

ON CONFLICT(doctype_id, scope_type_id) DO NOTHING;


INSERT INTO doctype_scope_mappings
  (doctype_id, scope_type_id, resolution_key)

SELECT
  d.id,
  s.id,
  'direct.department_id'
FROM doctypes d
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE d.doctype_name IN (
  'Department',
  'Faculty'
)

ON CONFLICT(doctype_id, scope_type_id) DO NOTHING;


INSERT INTO doctype_scope_mappings
  (doctype_id, scope_type_id, resolution_key)

SELECT
  d.id,
  s.id,
  'course.department_id'
FROM doctypes d
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE d.doctype_name = 'Course'

ON CONFLICT(doctype_id, scope_type_id) DO NOTHING;


INSERT INTO doctype_scope_mappings
  (doctype_id, scope_type_id, resolution_key)

SELECT
  d.id,
  s.id,
  'course.department_id'
FROM doctypes d
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE d.doctype_name = 'Subject'

ON CONFLICT(doctype_id, scope_type_id) DO NOTHING;


INSERT INTO doctype_scope_mappings
  (doctype_id, scope_type_id, resolution_key)

SELECT
  d.id,
  s.id,
  'course.department_id'
FROM doctypes d
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE d.doctype_name = 'Enrollment'

ON CONFLICT(doctype_id, scope_type_id) DO NOTHING;


INSERT INTO doctype_scope_mappings
  (doctype_id, scope_type_id, resolution_key)

SELECT
  d.id,
  s.id,
  'enrollment.course.department_id'
FROM doctypes d
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE d.doctype_name = 'Attendance'

ON CONFLICT(doctype_id, scope_type_id) DO NOTHING;


-- ------------------------------------------------------------
-- 14. Business action requirements
-- ------------------------------------------------------------

-- mark_attendance
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Faculty'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'mark_attendance'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'mark_attendance'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Enrollment'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'mark_attendance'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Subject'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'mark_attendance'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Attendance'
JOIN permissions p
  ON p.action_name = 'mark_attendance'
WHERE ba.action_code = 'mark_attendance'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- approve_attendance
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Attendance'
JOIN permissions p
  ON p.action_name = 'approve_attendance'
WHERE ba.action_code = 'approve_attendance'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- enroll_student
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'enroll_student'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Course'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'enroll_student'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Enrollment'
JOIN permissions p
  ON p.action_name = 'create'
WHERE ba.action_code = 'enroll_student'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- transfer_student
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name = 'update'
WHERE ba.action_code = 'transfer_student'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Enrollment'
JOIN permissions p
  ON p.action_name = 'update'
WHERE ba.action_code = 'transfer_student'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- assign_faculty
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Faculty'
JOIN permissions p
  ON p.action_name = 'read'
WHERE ba.action_code = 'assign_faculty'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Subject'
JOIN permissions p
  ON p.action_name = 'assign_faculty'
WHERE ba.action_code = 'assign_faculty'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- promote_student
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name = 'promote'
WHERE ba.action_code = 'promote_student'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- generate_student_report
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name = 'generate_report'
WHERE ba.action_code = 'generate_student_report'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- export_department_data
INSERT INTO business_action_requirements
  (business_action_id, doctype_id, permission_id)

SELECT
  ba.id,
  d.id,
  p.id
FROM business_actions ba
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name = 'export'
WHERE ba.action_code = 'export_department_data'

ON CONFLICT(
  business_action_id,
  doctype_id,
  permission_id
) DO NOTHING;


-- ------------------------------------------------------------
-- 15. Role business actions
-- ------------------------------------------------------------

-- SUPER_ADMIN: everything at SYSTEM scope

INSERT INTO role_business_actions
  (role_id, business_action_id, effect, scope_type_id)

SELECT
  r.id,
  ba.id,
  'ALLOW',
  s.id
FROM roles r
CROSS JOIN business_actions ba
JOIN scope_types s
  ON s.scope_code = 'SYSTEM'
WHERE r.role_name = 'SUPER_ADMIN'

ON CONFLICT(role_id, business_action_id) DO NOTHING;


-- ADMIN: system-wide business operations

INSERT INTO role_business_actions
  (role_id, business_action_id, effect, scope_type_id)

SELECT
  r.id,
  ba.id,
  'ALLOW',
  s.id
FROM roles r
CROSS JOIN business_actions ba
JOIN scope_types s
  ON s.scope_code = 'SYSTEM'
WHERE r.role_name = 'ADMIN'

ON CONFLICT(role_id, business_action_id) DO NOTHING;


-- HOD: department-scoped operations

INSERT INTO role_business_actions
  (role_id, business_action_id, effect, scope_type_id)

SELECT
  r.id,
  ba.id,
  'ALLOW',
  s.id
FROM roles r
JOIN business_actions ba
  ON ba.action_code IN (
    'approve_attendance',
    'assign_faculty',
    'promote_student',
    'generate_student_report',
    'export_department_data'
  )
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE r.role_name = 'HOD'

ON CONFLICT(role_id, business_action_id) DO NOTHING;


-- FACULTY: department-scoped operations

INSERT INTO role_business_actions
  (role_id, business_action_id, effect, scope_type_id)

SELECT
  r.id,
  ba.id,
  'ALLOW',
  s.id
FROM roles r
JOIN business_actions ba
  ON ba.action_code IN (
    'mark_attendance',
    'generate_student_report'
  )
JOIN scope_types s
  ON s.scope_code = 'DEPARTMENT'
WHERE r.role_name = 'FACULTY'

ON CONFLICT(role_id, business_action_id) DO NOTHING;


-- STUDENT: own-record operation

INSERT INTO role_business_actions
  (role_id, business_action_id, effect, scope_type_id)

SELECT
  r.id,
  ba.id,
  'ALLOW',
  s.id
FROM roles r
JOIN business_actions ba
  ON ba.action_code = 'enroll_student'
JOIN scope_types s
  ON s.scope_code = 'OWN'
WHERE r.role_name = 'STUDENT'

ON CONFLICT(role_id, business_action_id) DO NOTHING;