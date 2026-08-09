/**
 * The visual guides. Every image is a real screenshot of the real app,
 * taken against a server seeded for the purpose, with each step describing
 * the actual screen instead of a general instruction.
 */

type GuideStep = {
  title: string;
  body: string;
  image: string;
  alt: string;
};

export type Guide = {
  slug: string;
  question: string;
  summary: string;
  minutes: number;
  steps: GuideStep[];
};

export const guides: Guide[] = [
  {
    slug: "add-someone",
    question: "How do I let someone else use my drive?",
    summary:
      "Everyone gets their own account and their own files. You send them a code, they pick their own password.",
    minutes: 2,
    steps: [
      {
        title: "Open Settings, then Users",
        body: "Only an admin sees this. It lists everyone on the server and how much space each of them is using.",
        image: "/guides/invite-1-users.png",
        alt: "The Users section of Settings, listing one account with its storage usage",
      },
      {
        title: "Press Invite someone and give the invite a name",
        body: "The name is only so you remember who you made it for. It does not become their username, and they choose that themselves.",
        image: "/guides/invite-2-dialog.png",
        alt: "The invite dialog asking who the invite is for",
      },
      {
        title: "Send them the code",
        body: "Send the code or the link however you already talk to them. On the same network they can scan the square instead. They enter it in the app, pick a username and a password, and they are in with their own private space.",
        image: "/guides/invite-3-code.png",
        alt: "The invite dialog showing a QR code, the invite code, and buttons to copy the code or the link",
      },
    ],
  },
  {
    slug: "share-a-link",
    question: "How do I send a file to someone who has no account?",
    summary:
      "Make a link. Anyone with it can open the file, and you can put a password on it or have it expire.",
    minutes: 2,
    steps: [
      {
        title: "Right click the file or folder, then Share",
        body: "On a phone, press and hold instead. Everything you can do to a file lives in this one menu.",
        image: "/guides/share-1-menu.png",
        alt: "The right click menu on a folder, showing Open, Starred, Rename, Folder color, Move, Share and Trash",
      },
      {
        title: "Choose People or Link",
        body: "People is for someone who already has an account here, and you can decide whether they can edit or only look. Link is for everyone else.",
        image: "/guides/share-2-people.png",
        alt: "The share dialog with People and Link tabs, showing view and edit permissions",
      },
      {
        title: "Create the link and copy it",
        body: "Turn downloads off if they should only view it. Give it an expiry date, or a password, or both. Revoke it whenever you like and the link stops working immediately.",
        image: "/guides/share-3-link.png",
        alt: "The link tab showing the share link, an allow download switch, expiry and password rows, and a revoke button",
      },
    ],
  },
  {
    slug: "add-a-device",
    question: "How do I get my drive on my phone or another computer?",
    summary:
      "Install the app, and it looks for your server on the network by itself.",
    minutes: 2,
    steps: [
      {
        title: "Open the app on the new device",
        body: "The same app runs on Windows, macOS, Linux, Android and iOS, and there is a browser version served by the server itself.",
        image: "/guides/connect-welcome.png",
        alt: "The welcome screen explaining that files stay on hardware you own",
      },
      {
        title: "Pick your server, or type its address",
        body: "On the same network it usually finds itself. If it does not, type the address, which looks like 192.168.1.10. Then sign in with your username and password.",
        image: "/guides/connect-server.png",
        alt: "The connect screen scanning the network, with a field to type a server address",
      },
    ],
  },
  {
    slug: "protect-my-account",
    question: "How do I stop someone signing in as me?",
    summary:
      "Turn on two factor. An admin account has to, because it can reach everything.",
    minutes: 3,
    steps: [
      {
        title: "Scan the code with an authenticator app",
        body: "Any of them work: Google Authenticator, Aegis, 1Password, Bitwarden. Open Settings, then Two-factor authentication, and point your phone at the square.",
        image: "/guides/twofactor-qr.png",
        alt: "The two factor screen showing a QR code to scan and a field for the six digit code",
      },
      {
        title: "Or type the key by hand",
        body: "Switch to Enter a key if the authenticator is on the same device, or you keep your codes in a password manager. Then type the six digit code it shows you and save the recovery codes somewhere that is not this device. Each one signs you in once if you ever lose the phone.",
        image: "/guides/twofactor-key.png",
        alt: "The two factor screen switched to show the setup key as text, with recovery codes beside it",
      },
    ],
  },
  {
    slug: "get-files-in",
    question: "How do I get my files in?",
    summary:
      "Drag them onto the window. Whole folders keep their shape.",
    minutes: 1,
    steps: [
      {
        title: "Drag files or folders straight onto the app",
        body: "Drop them anywhere to put them in the folder you are looking at, or drop them onto a folder to put them inside it. A dropped folder arrives as that folder, with everything inside it and any folders inside that. You can also press Upload if you prefer to pick them.",
        image: "/guides/files-overview.png",
        alt: "The files screen with folders, an Upload button, and a search field",
      },
      {
        title: "Photos and videos also collect in the Gallery",
        body: "Anything you upload that is a picture or a clip shows up here as well, newest first, without you filing it anywhere.",
        image: "/guides/gallery-photos.png",
        alt: "The gallery screen showing uploaded photos in a grid",
      },
    ],
  },
];

export function guideBySlug(slug: string): Guide | undefined {
  return guides.find((guide) => guide.slug === slug);
}
