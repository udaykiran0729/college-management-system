CREATE TABLE IF NOT EXISTS role_permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  role TEXT NOT NULL,
  permission TEXT NOT NULL,
  UNIQUE(role, permission)
);

INSERT INTO role_permissions (role, permission) VALUES
  ('SUPER_ADMIN', 'student:create'),
  ('SUPER_ADMIN', 'student:read'),
  ('SUPER_ADMIN', 'student:update'),
  ('SUPER_ADMIN', 'student:delete'),

  ('ADMIN', 'student:create'),
  ('ADMIN', 'student:read'),
  ('ADMIN', 'student:update'),
  ('ADMIN', 'student:delete'),

  ('HOD', 'student:read'),
  ('HOD', 'student:update'),

  ('FACULTY', 'student:read'),
  ('FACULTY', 'student:update'),

  ('STUDENT', 'student:read');