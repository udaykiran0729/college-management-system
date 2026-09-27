-- ============================================================
-- 0017: Department-scoped access and user scope assignments
-- ============================================================

-- HOD and FACULTY are department-scoped.
UPDATE roles SET access_mode = 'SCOPED' WHERE role_name IN ('HOD', 'FACULTY');
UPDATE roles SET access_mode = 'SYSTEM' WHERE role_name IN ('ADMIN', 'SUPER_ADMIN');
UPDATE roles SET access_mode = 'OWN' WHERE role_name = 'STUDENT';

-- Faculty: department-scoped academic visibility and student maintenance.
INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'DEPARTMENT'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'FACULTY'
  AND d.doctype_name IN ('Department','Course','Student','Faculty','Subject','Enrollment','Attendance')
  AND p.action_name IN ('read')
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'DEPARTMENT', is_active = 1;

INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'DEPARTMENT'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'FACULTY'
  AND d.doctype_name = 'Student'
  AND p.action_name = 'update'
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'DEPARTMENT', is_active = 1;

-- HOD: department-scoped academic visibility and student/faculty maintenance.
INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'DEPARTMENT'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'HOD'
  AND d.doctype_name IN ('Department','Course','Student','Faculty','Subject','Enrollment','Attendance')
  AND p.action_name = 'read'
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'DEPARTMENT', is_active = 1;

INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'DEPARTMENT'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'HOD'
  AND d.doctype_name IN ('Student','Faculty')
  AND p.action_name = 'update'
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'DEPARTMENT', is_active = 1;

-- Ensure system roles retain system-wide access for existing permissions.
UPDATE doctype_role_permissions
SET scope = 'SYSTEM'
WHERE role_id IN (SELECT id FROM roles WHERE role_name IN ('ADMIN','SUPER_ADMIN'));

-- Current demo accounts are assigned to the CSE department (department id is
-- resolved by department_code so this remains portable across environments).
INSERT INTO user_scope_rules (user_id, scope_type_id, scope_id, is_active)
SELECT u.id, st.id, d.id, 1
FROM users u
JOIN scope_types st ON st.scope_code = 'DEPARTMENT'
JOIN departments d ON d.department_code = 'CSE-DEPT'
WHERE u.username IN ('faculty2026','hod2026')
ON CONFLICT(user_id, scope_type_id, scope_id)
DO UPDATE SET is_active = 1;

-- Student demo account remains linked through users.student_id and OWN access.

-- Attendance workflow atomic permissions.
INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'DEPARTMENT'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'FACULTY'
  AND d.doctype_name = 'Attendance'
  AND p.action_name IN ('mark_attendance','update')
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'DEPARTMENT', is_active = 1;

INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'DEPARTMENT'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'HOD'
  AND d.doctype_name = 'Attendance'
  AND p.action_name IN ('approve_attendance','update')
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'DEPARTMENT', is_active = 1;

-- Student role is limited to its own academic records.
INSERT INTO doctype_role_permissions (role_id, doctype_id, permission_id, scope)
SELECT r.id, d.id, p.id, 'OWN'
FROM roles r CROSS JOIN doctypes d CROSS JOIN permissions p
WHERE r.role_name = 'STUDENT'
  AND d.doctype_name IN ('Student','Enrollment','Attendance')
  AND p.action_name = 'read'
ON CONFLICT(role_id, doctype_id, permission_id)
DO UPDATE SET scope = 'OWN', is_active = 1;

-- Backfill legacy student academic links so department scope is enforceable.
UPDATE students
SET
  course_id = (
    SELECT c.id FROM courses c
    WHERE LOWER(TRIM(students.course)) = LOWER(TRIM(c.course_name))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(c.course_name, 'B.Tech ', '')))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(REPLACE(c.course_name, 'B.Tech ', ''), ' Engineering', '')))
    ORDER BY c.id
    LIMIT 1
  ),
  department_id = (
    SELECT c.department_id FROM courses c
    WHERE LOWER(TRIM(students.course)) = LOWER(TRIM(c.course_name))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(c.course_name, 'B.Tech ', '')))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(REPLACE(c.course_name, 'B.Tech ', ''), ' Engineering', '')))
    ORDER BY c.id
    LIMIT 1
  ),
  branch_id = (
    SELECT d.branch_id
    FROM courses c JOIN departments d ON d.id = c.department_id
    WHERE LOWER(TRIM(students.course)) = LOWER(TRIM(c.course_name))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(c.course_name, 'B.Tech ', '')))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(REPLACE(c.course_name, 'B.Tech ', ''), ' Engineering', '')))
    ORDER BY c.id
    LIMIT 1
  )
WHERE EXISTS (
  SELECT 1 FROM courses c
  WHERE LOWER(TRIM(students.course)) = LOWER(TRIM(c.course_name))
     OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(c.course_name, 'B.Tech ', '')))
       OR LOWER(TRIM(students.course)) = LOWER(TRIM(REPLACE(REPLACE(c.course_name, 'B.Tech ', ''), ' Engineering', '')))
);
