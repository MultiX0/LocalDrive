-- initial schema, see plan section 3.3
-- all timestamps are unix milliseconds

CREATE TABLE users (
  id                    TEXT PRIMARY KEY,
  email                 TEXT UNIQUE,
  username              TEXT NOT NULL UNIQUE,
  display_name          TEXT NOT NULL DEFAULT '',
  password_hash         TEXT NOT NULL,
  must_change_password  INTEGER NOT NULL DEFAULT 0,
  role                  TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin','member')),
  quota_bytes           INTEGER NOT NULL DEFAULT 0,
  quota_bytes_used      INTEGER NOT NULL DEFAULT 0,
  avatar_seed           TEXT NOT NULL,
  totp_secret           TEXT,
  totp_enabled          INTEGER NOT NULL DEFAULT 0,
  totp_recovery_json    TEXT,
  disabled_at           INTEGER,
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL
);

CREATE UNIQUE INDEX idx_users_username_lower ON users (lower(username));

CREATE TABLE sessions (
  id                  TEXT PRIMARY KEY,
  user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name         TEXT NOT NULL DEFAULT '',
  platform            TEXT NOT NULL DEFAULT '',
  status              TEXT NOT NULL CHECK (status IN ('pending','active','revoked','denied')),
  refresh_token_hash  TEXT,
  ip                  TEXT NOT NULL DEFAULT '',
  user_agent          TEXT NOT NULL DEFAULT '',
  created_at          INTEGER NOT NULL,
  last_seen_at        INTEGER NOT NULL,
  expires_at          INTEGER,
  approved_at         INTEGER,
  approved_by         TEXT,
  revoked_at          INTEGER
);

CREATE INDEX idx_sessions_user ON sessions (user_id, status);
CREATE INDEX idx_sessions_refresh ON sessions (refresh_token_hash);

CREATE TABLE invites (
  id          TEXT PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,
  label       TEXT NOT NULL DEFAULT '',
  created_by  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  INTEGER,
  used_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  used_at     INTEGER,
  revoked_at  INTEGER,
  created_at  INTEGER NOT NULL
);

CREATE TABLE libraries (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  root_path    TEXT NOT NULL UNIQUE,
  kind         TEXT NOT NULL CHECK (kind IN ('internal','external','network','pooled')),
  is_external  INTEGER NOT NULL DEFAULT 0,
  is_default   INTEGER NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'online' CHECK (status IN ('online','offline')),
  device_id    TEXT,
  members_json TEXT,
  bytes_used   INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);

CREATE TABLE nodes (
  id                     TEXT PRIMARY KEY,
  parent_id              TEXT REFERENCES nodes(id) ON DELETE CASCADE,
  owner_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  library_id             TEXT NOT NULL REFERENCES libraries(id),
  name                   TEXT NOT NULL,
  type                   TEXT NOT NULL CHECK (type IN ('file','folder')),
  mime_type              TEXT NOT NULL DEFAULT '',
  size_bytes             INTEGER NOT NULL DEFAULT 0,
  checksum_sha256        TEXT,
  color                  TEXT,
  has_thumbnail          INTEGER NOT NULL DEFAULT 0,
  thumbnail_generated_at INTEGER,
  version_count          INTEGER NOT NULL DEFAULT 1,
  created_at             INTEGER NOT NULL,
  updated_at             INTEGER NOT NULL,
  trashed_at             INTEGER,
  deleted_at             INTEGER
);

CREATE INDEX idx_nodes_parent ON nodes (parent_id, deleted_at);
CREATE INDEX idx_nodes_owner ON nodes (owner_id, deleted_at);
CREATE INDEX idx_nodes_checksum ON nodes (checksum_sha256);
CREATE INDEX idx_nodes_library ON nodes (library_id);
CREATE INDEX idx_nodes_trashed ON nodes (trashed_at);
CREATE INDEX idx_nodes_updated ON nodes (owner_id, updated_at DESC);

CREATE TABLE node_versions (
  id               TEXT PRIMARY KEY,
  node_id          TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  size_bytes       INTEGER NOT NULL,
  checksum_sha256  TEXT NOT NULL,
  mime_type        TEXT NOT NULL DEFAULT '',
  created_by       TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at       INTEGER NOT NULL
);

CREATE INDEX idx_versions_node ON node_versions (node_id, created_at DESC);
CREATE INDEX idx_versions_checksum ON node_versions (checksum_sha256);

CREATE TABLE stars (
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  node_id     TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  created_at  INTEGER NOT NULL,
  PRIMARY KEY (user_id, node_id)
);

CREATE TABLE permissions (
  id          TEXT PRIMARY KEY,
  node_id     TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('viewer','editor')),
  created_by  TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at  INTEGER NOT NULL,
  UNIQUE (node_id, user_id)
);

CREATE INDEX idx_permissions_user ON permissions (user_id);

CREATE TABLE shares (
  id              TEXT PRIMARY KEY,
  node_id         TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  token           TEXT NOT NULL UNIQUE,
  password_hash   TEXT,
  expires_at      INTEGER,
  allow_download  INTEGER NOT NULL DEFAULT 1,
  created_by      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at      INTEGER NOT NULL,
  revoked_at      INTEGER
);

CREATE INDEX idx_shares_node ON shares (node_id);
CREATE INDEX idx_shares_creator ON shares (created_by, revoked_at);

CREATE TABLE server_settings (
  id                       INTEGER PRIMARY KEY CHECK (id = 1),
  server_id                TEXT NOT NULL,
  server_name              TEXT NOT NULL,
  require_device_approval  INTEGER NOT NULL DEFAULT 1,
  enable_lan_discovery     INTEGER NOT NULL DEFAULT 1,
  allow_self_registration  INTEGER NOT NULL DEFAULT 0,
  trash_retention_days     INTEGER NOT NULL DEFAULT 30,
  version_retention_count  INTEGER NOT NULL DEFAULT 20,
  version_retention_days   INTEGER NOT NULL DEFAULT 180,
  setup_completed_at       INTEGER,
  created_at               INTEGER NOT NULL,
  updated_at               INTEGER NOT NULL
);

CREATE TABLE activity_log (
  id             TEXT PRIMARY KEY,
  user_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  node_id        TEXT,
  action         TEXT NOT NULL,
  metadata_json  TEXT NOT NULL DEFAULT '{}',
  ip             TEXT NOT NULL DEFAULT '',
  created_at     INTEGER NOT NULL
);

CREATE INDEX idx_activity_created ON activity_log (created_at DESC);
CREATE INDEX idx_activity_user ON activity_log (user_id, created_at DESC);
CREATE INDEX idx_activity_node ON activity_log (node_id, created_at DESC);

CREATE TABLE idempotency_keys (
  key            TEXT NOT NULL,
  user_id        TEXT NOT NULL,
  endpoint       TEXT NOT NULL,
  response_json  TEXT NOT NULL,
  created_at     INTEGER NOT NULL,
  PRIMARY KEY (key, user_id, endpoint)
);

CREATE INDEX idx_idempotency_created ON idempotency_keys (created_at);
