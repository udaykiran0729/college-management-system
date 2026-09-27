-- ============================================================
-- PHASE 3A: RBAC / DOCTYPE MASTER TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  role_name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS doctypes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doctype_name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action_name TEXT NOT NULL UNIQUE,
  description TEXT
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  role_id INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1,

  FOREIGN KEY (role_id)
    REFERENCES roles(id)
);

-- ============================================================
-- SEED ROLES
-- ============================================================

INSERT INTO roles
  (role_name, description)
VALUES
  ('SUPER_ADMIN', 'Full system administrator'),
  ('ADMIN', 'Administrative user'),
  ('HOD', 'Head of Department'),
  ('FACULTY', 'Faculty member'),
  ('STUDENT', 'Student user')
ON CONFLICT(role_name) DO NOTHING;

-- ============================================================
-- SEED DOCTYPES
-- ============================================================

INSERT INTO doctypes
  (doctype_name, description)
VALUES
  ('Branch', 'Academic branch'),
  ('Department', 'Academic department'),
  ('Course', 'Academic course'),
  ('Student', 'Student master record'),
  ('Faculty', 'Faculty master record'),
  ('Subject', 'Course subject'),
  ('Enrollment', 'Student course enrollment'),
  ('Attendance', 'Student attendance record'),
  ('User', 'System user'),
  ('Role', 'Security role'),
  ('Role Permission', 'Role authorization mapping')
ON CONFLICT(doctype_name) DO NOTHING;

-- ============================================================
-- SEED PERMISSIONS / ACTIONS
-- ============================================================

INSERT INTO permissions
  (action_name, description)
VALUES
  ('create', 'Create a document'),
  ('read', 'Read/view a document'),
  ('update', 'Update a document'),
  ('delete', 'Delete a document')
ON CONFLICT(action_name) DO NOTHING;