-- ============================================================
-- PHASE 1: ACADEMIC MASTER DATA
-- ============================================================

-- BRANCHES
INSERT INTO branches
  (branch_code, branch_name, description)
VALUES
  ('CSE', 'Computer Science and Engineering',
   'Computer Science and Engineering branch'),

  ('ECE', 'Electronics and Communication Engineering',
   'Electronics and Communication Engineering branch'),

  ('EEE', 'Electrical and Electronics Engineering',
   'Electrical and Electronics Engineering branch'),

  ('ME', 'Mechanical Engineering',
   'Mechanical Engineering branch');


-- DEPARTMENTS
INSERT INTO departments
  (department_code, department_name, branch_id, description)
VALUES
  ('CSE-DEPT',
   'Computer Science Department',
   (SELECT id FROM branches WHERE branch_code = 'CSE'),
   'Department under CSE branch'),

  ('IT-DEPT',
   'Information Technology Department',
   (SELECT id FROM branches WHERE branch_code = 'CSE'),
   'Information Technology department'),

  ('ECE-DEPT',
   'Electronics Department',
   (SELECT id FROM branches WHERE branch_code = 'ECE'),
   'Department under ECE branch'),

  ('EEE-DEPT',
   'Electrical Department',
   (SELECT id FROM branches WHERE branch_code = 'EEE'),
   'Department under EEE branch'),

  ('ME-DEPT',
   'Mechanical Department',
   (SELECT id FROM branches WHERE branch_code = 'ME'),
   'Department under Mechanical branch');


-- COURSES
INSERT INTO courses
  (course_code, course_name, department_id, duration_years, description)
VALUES
  ('BTECH-CSE',
   'B.Tech Computer Science',
   (SELECT id FROM departments WHERE department_code = 'CSE-DEPT'),
   4,
   'Bachelor of Technology in Computer Science'),

  ('BTECH-IT',
   'B.Tech Information Technology',
   (SELECT id FROM departments WHERE department_code = 'IT-DEPT'),
   4,
   'Bachelor of Technology in Information Technology'),

  ('BTECH-ECE',
   'B.Tech Electronics and Communication',
   (SELECT id FROM departments WHERE department_code = 'ECE-DEPT'),
   4,
   'Bachelor of Technology in Electronics and Communication'),

  ('BTECH-EEE',
   'B.Tech Electrical and Electronics',
   (SELECT id FROM departments WHERE department_code = 'EEE-DEPT'),
   4,
   'Bachelor of Technology in Electrical and Electronics'),

  ('BTECH-ME',
   'B.Tech Mechanical Engineering',
   (SELECT id FROM departments WHERE department_code = 'ME-DEPT'),
   4,
   'Bachelor of Technology in Mechanical Engineering');