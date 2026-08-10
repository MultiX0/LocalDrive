/**
 * Every path the server serves, ported from
 * localdrive/lib/core/constants/api_endpoints.dart.
 *
 * Kept as one list so a route that moves on the server moves in exactly one
 * place here.
 */
const prefix = "/api/v1";

export const Api = {
  prefix,

  // connecting and accounts
  status: `${prefix}/status`,
  setup: `${prefix}/setup`,
  register: `${prefix}/auth/register`,
  login: `${prefix}/auth/login`,
  refresh: `${prefix}/auth/refresh`,
  logout: `${prefix}/auth/logout`,
  checkInvite: (code: string) => `${prefix}/invites/${encodeURIComponent(code)}/check`,
  sessionStatus: (id: string) => `${prefix}/auth/session/${encodeURIComponent(id)}/status`,

  // the signed in account
  me: `${prefix}/me`,
  mePassword: `${prefix}/me/password`,
  meProfile: `${prefix}/me/profile`,
  totpBegin: `${prefix}/auth/2fa/begin`,
  totpVerify: `${prefix}/auth/2fa/verify`,
  totpDisable: `${prefix}/auth/2fa/disable`,
  // the directory everyone can read, for picking somebody to share with:
  // id, name and avatar seed only
  users: `${prefix}/users`,
  // the full accounts, admin only: role, quota, and the rest
  adminUsers: `${prefix}/admin/users`,

  // the tree
  nodes: `${prefix}/nodes`,
  folder: `${prefix}/nodes/folder`,
  node: (id: string) => `${prefix}/nodes/${id}`,
  nodePath: (id: string) => `${prefix}/nodes/${id}/path`,
  star: (id: string) => `${prefix}/nodes/${id}/star`,
  restore: (id: string) => `${prefix}/nodes/${id}/restore`,
  permanent: (id: string) => `${prefix}/nodes/${id}/permanent`,
  preview: (id: string) => `${prefix}/nodes/${id}/preview`,
  download: (id: string) => `${prefix}/nodes/${id}/download`,
  thumbnail: (id: string) => `${prefix}/nodes/${id}/thumbnail`,
  versions: (id: string) => `${prefix}/nodes/${id}/versions`,
  restoreVersion: (id: string, versionId: string) =>
    `${prefix}/nodes/${id}/versions/${versionId}/restore`,

  // sharing
  nodeShares: (id: string) => `${prefix}/nodes/${id}/shares`,
  createShare: (id: string) => `${prefix}/nodes/${id}/share`,
  share: (id: string) => `${prefix}/shares/${id}`,
  myShares: `${prefix}/shares`,
  permissions: (id: string) => `${prefix}/nodes/${id}/permissions`,
  permission: (nodeId: string, userId: string) =>
    `${prefix}/nodes/${nodeId}/permissions/${userId}`,

  // a public link, which is outside the api prefix on purpose
  publicShare: (token: string) => `/s/${token}`,
  publicShareDownload: (token: string) => `/s/${token}/download`,
  publicShareThumbnail: (token: string) => `/s/${token}/thumbnail`,
  publicShareChildren: (token: string) => `/s/${token}/children`,

  uploads: `${prefix}/uploads`,

  // storage
  libraries: `${prefix}/libraries`,
  library: (id: string) => `${prefix}/libraries/${id}`,
  librarySetDefault: (id: string) => `${prefix}/libraries/${id}/set-default`,
  libraryEject: (id: string) => `${prefix}/libraries/${id}/eject`,
  drives: `${prefix}/admin/drives`,
  mountDrive: (id: string) => `${prefix}/admin/drives/${id}/mount`,

  // admin and activity
  settings: `${prefix}/settings`,
  activity: `${prefix}/activity`,
  invites: `${prefix}/invites`,
  // the signed-in devices are the account's sessions; /devices only carries
  // the approve and deny actions for one that is waiting
  sessions: `${prefix}/sessions`,
  session: (id: string) => `${prefix}/sessions/${id}`,
  devices: `${prefix}/devices`,
  pendingDevices: `${prefix}/devices/pending`,
  trash: `${prefix}/trash`,
  search: `${prefix}/search`,
} as const;

/** The one port a Local Drive server serves on. Not 443, so it does not
 *  collide with whatever else is on the machine someone is hosting from. */
export const DEFAULT_PORT = 7443;
