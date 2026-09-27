-- ============================================================
-- PHASE 2: COURSES FOR EXISTING STUDENT VALUES
-- ============================================================

INSERT INTO courses
  (course_code, course_name, department_id, duration_years, description)
SELECT
  'BTECH-SE',
  'Software Engineering',
  d.id,
  4,
  'Legacy course value normalized into the Course DocType'
FROM departments d
WHERE d.department_code = 'CSE-DEPT'
  AND NOT EXISTS (
    SELECT 1
    FROM courses
    WHERE course_code = 'BTECH-SE'
  );

INSERT INTO courses
  (course_code, course_name, department_id, duration_years, description)
SELECT
  'BTECH-DS',
  'Data Science',
  d.id,
  4,
  'Legacy course value normalized into the Course DocType'
FROM departments d
WHERE d.department_code = 'IT-DEPT'
  AND NOT EXISTS (
    SELECT 1
    FROM courses
    WHERE course_code = 'BTECH-DS'
  );