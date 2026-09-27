-- ============================================================
-- 0016: User API tokens
-- ============================================================

CREATE TABLE IF NOT EXISTS user_api_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  user_id INTEGER NOT NULL,

  token_hash TEXT NOT NULL UNIQUE,

  token_name TEXT NOT NULL DEFAULT 'default',

  is_active INTEGER NOT NULL DEFAULT 1,

  expires_at TEXT,

  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

  last_used_at TEXT,

  FOREIGN KEY (user_id)
    REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_user_api_tokens_user_id
ON user_api_tokens(user_id);

CREATE INDEX IF NOT EXISTS idx_user_api_tokens_token_hash
ON user_api_tokens(token_hash);