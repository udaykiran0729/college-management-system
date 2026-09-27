-- ============================================================
-- PHASE 2: ACADEMIC RELATIONSHIP / TRANSACTION TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS faculty (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  faculty_code TEXT NOT NULL UNIQUE,
  faculty_name TEXT NOT NULL,
  email TEXT UNIQUE,
  department_id INTEGER NOT NULL,
  designation TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,

  FOREIGN KEY (department_id)
    REFERENCES departments(id)
);

CREATE TABLE IF NOT EXISTS subjects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_code TEXT NOT NULL UNIQUE,
  subject_name TEXT NOT NULL,
  course_id INTEGER NOT NULL,
  semester INTEGER NOT NULL,
  credits INTEGER NOT NULL DEFAULT 3,
  is_active INTEGER NOT NULL DEFAULT 1,

  FOREIGN KEY (course_id)
    REFERENCES courses(id)
);

CREATE TABLE IF NOT EXISTS enrollments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL,
  course_id INTEGER NOT NULL,
  academic_year TEXT NOT NULL,
  semester INTEGER NOT NULL,
  enrollment_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status TEXT NOT NULL DEFAULT 'ACTIVE',

  UNIQUE (student_id, course_id, academic_year, semester),

  FOREIGN KEY (student_id)
    REFERENCES students(id),

  FOREIGN KEY (course_id)
    REFERENCES courses(id)
);

CREATE TABLE IF NOT EXISTS attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  enrollment_id INTEGER NOT NULL,
  subject_id INTEGER NOT NULL,
  attendance_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PRESENT',
  marked_by_faculty_id INTEGER,

  UNIQUE (enrollment_id, subject_id, attendance_date),

  FOREIGN KEY (enrollment_id)
    REFERENCES enrollments(id),

  FOREIGN KEY (subject_id)
    REFERENCES subjects(id),

  FOREIGN KEY (marked_by_faculty_id)
    REFERENCES faculty(id)
);