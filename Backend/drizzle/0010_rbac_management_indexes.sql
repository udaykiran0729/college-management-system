-- ============================================================
-- PHASE 3E: RBAC MANAGEMENT INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_users_role_id
ON users(role_id);

CREATE INDEX IF NOT EXISTS idx_doctype_role_permissions_role
ON doctype_role_permissions(role_id);

CREATE INDEX IF NOT EXISTS idx_doctype_role_permissions_doctype
ON doctype_role_permissions(doctype_id);

CREATE INDEX IF NOT EXISTS idx_doctype_role_permissions_permission
ON doctype_role_permissions(permission_id);