import { categoryFor, type FileCategory } from "./tokens";

/** One node in the tree, as the server sends it. */
export interface NodeModel {
  id: string;
  parent_id: string;
  owner_id: string;
  library_id: string;
  name: string;
  type: "file" | "folder";
  mime_type: string;
  size_bytes: number;
  color?: string;
  has_thumbnail: boolean;
  image_width?: number;
  image_height?: number;
  taken_at?: number;
  version_count?: number;
  starred?: boolean;
  shared?: boolean;
  created_at: number;
  updated_at: number;
  trashed_at?: number;
  role?: string;
  /** Present only on something someone else owns. A face and a name read
   *  faster than a generic share glyph and answer the real question. */
  owner?: NodeOwner;
}

export interface NodeOwner {
  id: string;
  name: string;
  avatar_seed?: string;
}

export const isFolder = (n: NodeModel) => n.type === "folder";

export function categoryOf(n: NodeModel): FileCategory {
  return categoryFor(n.mime_type, isFolder(n));
}

/** One row of the shareable people directory. Deliberately thin: it is
 *  readable by everyone, so it carries no role, quota or email. */
export interface DirectoryUser {
  id: string;
  name: string;
  avatar_seed?: string;
}

export interface UserModel {
  id: string;
  username: string;
  display_name: string;
  email: string;
  role: "admin" | "member";
  avatar_seed?: string;
  quota_bytes: number;
  quota_bytes_used: number;
  must_change_password: boolean;
  totp_enabled: boolean;
  must_enable_totp: boolean;
  created_at: number;
}

export interface ShareModel {
  id: string;
  node_id: string;
  token: string;
  url: string;
  expires_at?: number;
  allow_download: boolean;
  password_protected: boolean;
  created_at: number;
}

export interface LibraryModel {
  id: string;
  name: string;
  path: string;
  is_default: boolean;
  online: boolean;
  removable?: boolean;
  total_bytes?: number;
  free_bytes?: number;
}

/** A signed-in device, as the server's session list sends it. */
export interface DeviceModel {
  id: string;
  device_name: string;
  platform: string;
  status: "active" | "pending" | "revoked";
  ip?: string;
  last_seen_at: number;
  created_at: number;
  approved_at?: number;
  current?: boolean;
}

export interface ActivityModel {
  id: string;
  user_id: string;
  username?: string;
  node_id?: string;
  action: string;
  ip?: string;
  created_at: number;
  metadata?: Record<string, unknown>;
}

/** What a login came back with. A held device gets a pending token instead
 *  of a session, which is what the waiting screen is for. */
export interface LoginResult {
  access_token?: string;
  refresh_token?: string;
  pending?: boolean;
  session_id?: string;
  user?: UserModel;
}
