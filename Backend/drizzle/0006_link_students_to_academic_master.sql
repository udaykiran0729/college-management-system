-- ============================================================
-- PHASE 2: LINK EXISTING STUDENTS TO ACADEMIC MASTER
-- ============================================================

ALTER TABLE students ADD COLUMN branch_id INTEGER;
ALTER TABLE students ADD COLUMN department_id INTEGER;
ALTER TABLE students ADD COLUMN course_id INTEGER;

-- Existing Software Engineering students
UPDATE students
SET
  course_id = (
    SELECT id
    FROM courses
    WHERE course_code = 'BTECH-SE'
    LIMIT 1
  ),
  department_id = (
    SELECT department_id
    FROM courses
    WHERE course_code = 'BTECH-SE'
    LIMIT 1
  ),
  branch_id = (
    SELECT b.id
    FROM branches b
    JOIN departments d
      ON d.branch_id = b.id
    WHERE d.department_code = 'CSE-DEPT'
    LIMIT 1
  )
WHERE LOWER(TRIM(course)) = 'software engineering';

-- Existing Data Science students
UPDATE students
SET
  course_id = (
    SELECT id
    FROM courses
    WHERE course_code = 'BTECH-DS'
    LIMIT 1
  ),
  department_id = (
    SELECT department_id
    FROM courses
    WHERE course_code = 'BTECH-DS'
    LIMIT 1
  ),
  branch_id = (
    SELECT b.id
    FROM branches b
    JOIN departments d
      ON d.branch_id = b.id
    WHERE d.department_code = 'IT-DEPT'
    LIMIT 1
  )
WHERE LOWER(TRIM(course)) = 'data science';