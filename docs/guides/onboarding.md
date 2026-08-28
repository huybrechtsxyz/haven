# Onboarding a Family Member

> How to give a family member access to haven — accounts, groups, MFA, and per-app first-login steps.

[← Back to Guide](./index.md)

This guide is split into two parts: **admin steps** (you create the accounts) and **family member steps** (what to hand off once their accounts exist). Two separate identity systems are involved — Authentik (SSO for Vaultwarden/Immich/Jellyfin/Nextcloud) and Infomaniak kSuite (email/calendar/contacts/kDrive, its own login, not SSO-linked).

---

## 1. Admin steps — create the accounts

### 1a. Authentik account (SSO)

Authentik provides single sign-on for Vaultwarden, Immich, Jellyfin, and Nextcloud. See [hearth.md](./hearth.md) for how Authentik itself is deployed.

1. Admin Interface → **Directory → Users → Create**
2. Fill in:
   - **Username:** first name, lowercase (e.g. `vincent`)
   - **Name:** full name
   - **Email:** `<name>@huybrechts.xyz` (their Infomaniak mailbox — see step 1b)
3. Set an initial password, or send an enrollment email (requires SMTP — see [infomaniak.md](../services/infomaniak.md) for the SMTP relay setup).
4. **Assign to a group** — Admin Interface → Directory → Users → select the user → **Groups** tab → Add to group:

   | Group     | Who                     | App access                                                         |
   | --------- | ----------------------- | ------------------------------------------------------------------ |
   | `admins`  | Technical administrator | All applications                                                   |
   | `parents` | Parents                 | All family applications (Vaultwarden, Immich, Jellyfin, Nextcloud) |
   | `members` | Everyone else (kids)    | Shared applications (Vaultwarden, Immich, Jellyfin, Nextcloud)     |

   > ⚠️ **This step is required.** Skipping it causes SSO logins to fail with "Permission denied — Policy binding returned result False" — the user authenticates successfully but isn't authorised for any application.

5. MFA is enforced automatically on first login (Authentik's blueprint binds a mandatory MFA stage) — the user will be prompted to enroll a TOTP authenticator the first time they sign in. No admin action needed here.

### 1b. Infomaniak kSuite account (email/calendar/contacts/kDrive)

Separate from Authentik — kSuite uses its own login, no SSO. See [infomaniak.md](../services/infomaniak.md) for full setup details.

1. Manager → kSuite → **Users** → Add user
2. Set email (`<name>@huybrechts.xyz`), display name, and an initial password (or send an invite)
3. Assign the appropriate kSuite licence
4. For children: set up mail-forwarding rules to both parents (see infomaniak.md's "Configure child mail forwarding")

---

## 2. Family member steps — first login, per app

Hand these off once both accounts above exist.

### Authentik (SSO login, one-time)

1. Go to `https://auth.huybrechts.xyz`, log in with the username/password given to you.
2. You'll be prompted to enroll MFA (TOTP) — recommended app: **Bitwarden Authenticator** (syncs seeds automatically once you're also set up in Vaultwarden, see below).
3. Store your backup/recovery codes somewhere safe (a parent can help store them in Vaultwarden once that's set up).

### Vaultwarden (password manager)

1. Go to `https://vault.huybrechts.xyz` → log in via Authentik SSO (same account, no separate password).
2. Install the **Bitwarden** browser extension and/or mobile app, and log in the same way (server URL: `https://vault.huybrechts.xyz`).
3. This is where you'll store your own passwords, TOTP seeds, and any backup codes going forward.

### Immich (photos)

1. Browser: `https://photos.huybrechts.xyz` → log in via Authentik SSO, or use the "Login with OAuth" button on the login screen.
2. Mobile app: install **Immich** (iOS/Android), server URL `https://photos.huybrechts.xyz` (no port needed — standard HTTPS), then use the OAuth/SSO login option.
3. Enable auto-backup in the app settings if you want your phone's photos/videos to upload automatically.

### Jellyfin (media streaming)

1. Browser: `https://jellyfin.huybrechts.xyz` → log in via the Authentik SSO option on the login screen.
2. Mobile/TV apps (Jellyfin has official apps for most platforms): server URL `https://jellyfin.huybrechts.xyz`, then choose SSO login.

### Nextcloud (family drive)

1. Browser: `https://drive.huybrechts.xyz` → log in via the Authentik SSO option.
2. Desktop sync client and mobile app: server URL `https://drive.huybrechts.xyz`, log in via SSO the same way.

### Infomaniak kSuite (email, calendar, contacts, kDrive)

Not connected to Authentik — log in directly at [manager.infomaniak.com](https://manager.infomaniak.com) (or the kSuite webmail/app) with the credentials from step 1b.

1. Enable MFA (TOTP) yourself: avatar → Security → Two-factor authentication. Recommended app: **Bitwarden Authenticator**.
2. Set up mail/calendar/contacts on your phone using kSuite's app or standard IMAP/CalDAV/CardDAV settings (see Infomaniak's own documentation for exact device setup instructions).
3. Store your TOTP backup codes in Vaultwarden once you have that set up (see above).

---

## Notes

- **Portainer** (`https://portainer.huybrechts.xyz`) is admin-only (local username/password auth, deliberately not SSO — see [hearth.md's design decision](./hearth.md#design-decision--portainer-stays-on-local-auth-not-sso)) — not part of a regular family member's onboarding.
- **WUD** (container update notifications) is also admin-only.
- If a family member can log in to Authentik but gets denied access to a specific app, the most common cause is a missing group assignment (see step 1a.4) — check Directory → Users → the user → Groups tab.
