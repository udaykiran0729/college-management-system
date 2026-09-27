-- ============================================================
-- PHASE 1: ACADEMIC MASTER TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS branches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch_code TEXT NOT NULL UNIQUE,
  branch_name TEXT NOT NULL,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS departments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  department_code TEXT NOT NULL UNIQUE,
  department_name TEXT NOT NULL,
  branch_id INTEGER NOT NULL,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,

  FOREIGN KEY (branch_id)
    REFERENCES branches(id)
);

CREATE TABLE IF NOT EXISTS courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  course_code TEXT NOT NULL UNIQUE,
  course_name TEXT NOT NULL,
  department_id INTEGER NOT NULL,
  duration_years INTEGER NOT NULL,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,

  FOREIGN KEY (department_id)
    REFERENCES departments(id)
);