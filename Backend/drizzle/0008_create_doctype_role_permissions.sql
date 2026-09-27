-- ============================================================
-- PHASE 3B: NORMALIZED DOCTYPE ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS doctype_role_permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  role_id INTEGER NOT NULL,
  doctype_id INTEGER NOT NULL,
  permission_id INTEGER NOT NULL,

  scope TEXT NOT NULL DEFAULT 'ALL',

  is_active INTEGER NOT NULL DEFAULT 1,

  UNIQUE (role_id, doctype_id, permission_id),

  FOREIGN KEY (role_id)
    REFERENCES roles(id),

  FOREIGN KEY (doctype_id)
    REFERENCES doctypes(id),

  FOREIGN KEY (permission_id)
    REFERENCES permissions(id)
);