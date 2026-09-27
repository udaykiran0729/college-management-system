-- ============================================================
-- PHASE 3C: MIGRATE EXISTING RBAC PERMISSIONS
-- Existing role_permissions is preserved.
-- New normalized table becomes the authorization source.
-- ============================================================

INSERT INTO doctype_role_permissions
  (role_id, doctype_id, permission_id, scope)
SELECT
  r.id,
  d.id,
  p.id,
  'ALL'
FROM role_permissions old_rp
JOIN roles r
  ON r.role_name = old_rp.role
JOIN doctypes d
  ON d.doctype_name = 'Student'
JOIN permissions p
  ON p.action_name =
    CASE old_rp.permission
      WHEN 'student:create' THEN 'create'
      WHEN 'student:read'   THEN 'read'
      WHEN 'student:update' THEN 'update'
      WHEN 'student:delete' THEN 'delete'
    END
WHERE old_rp.permission IN (
  'student:create',
  'student:read',
  'student:update',
  'student:delete'
)
ON CONFLICT(role_id, doctype_id, permission_id)
DO NOTHING;