# Syncing your RStudio Server with Nextcloud

Your RStudio server can keep one folder in sync with your Nextcloud: **RStudio-Server**. Files you put there in Nextcloud show up on the server, and files you create there on the server show up in Nextcloud. The sync runs automatically every 15 minutes, in both directions.

## What you need to do

1. **Find your Nextcloud address.** Log in at https://files.academiccloud.de. You'll be redirected to your institution's Nextcloud; copy the address from the browser bar (it looks like `https://<something>.academiccloud.de`).
2. **Create the folder `RStudio-Server`** at the top level of your Nextcloud (not inside another folder), exactly with this spelling.
3. **Create an app password.** In Nextcloud: your avatar (top right) → Settings → Security → "Devices & sessions". Enter `RStudio-Server` as app name and click *Create new app password*. Nextcloud shows a **username** and a **password** — copy both now; the password is shown only once.
4. **Send me** the address from step 1 and the username and password from step 3 as an encrypted message via chat.uni-goettingen.de.

The app password gives access to your whole Nextcloud account, not just this folder. It's only stored on your server. You can revoke it at any time under "Devices & sessions" — that stops the sync.

## Your server has no backup

Nothing on the server is backed up. If the server fails or is deleted, everything on it is gone — except what is in `RStudio-Server`, which also lives in your Nextcloud. Keep anything you can't afford to lose in that folder (or in a git repository you push regularly).

## Using it

On the server, the folder appears as **`RStudio-Server`** in your home directory — in RStudio's *Files* pane and in VS Code.

- **Don't rename, move or delete the `RStudio-Server` folder** — neither in Nextcloud nor on the server. The sync looks for exactly this name in exactly this place; if it's gone, the sync stops working, and a deleted folder may be deleted on the other side too.
- **Deleting a file deletes it on both sides.** It's a sync, not a backup. Nextcloud usually keeps deleted files in its trash bin for a while, so check there first if something is missing.
- **Only this folder is synced.** Everything else in your home directory on the server stays on the server only.
- **Changes take up to 15 minutes** to arrive on the other side. If you edit the same file in both places within that window, you'll find a second copy with "conflicted copy" in its name — keep the version you want and delete the other.
- **Keep large or generated files out of the folder** (R package libraries, `renv`, large intermediate results). They slow down every sync and fill your Nextcloud quota.
