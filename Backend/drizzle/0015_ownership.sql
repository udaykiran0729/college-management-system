-- ============================================================
-- 0015: User ownership mapping
-- ============================================================

ALTER TABLE users
ADD COLUMN student_id INTEGER;

CREATE INDEX IF NOT EXISTS idx_users_student_id
ON users(student_id);