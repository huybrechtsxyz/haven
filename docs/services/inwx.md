# INWX Domain Registrar

INWX is the domain registrar for all haven domains. It provides a simple API for DNS management, which we will use to automate DNS record creation and updates via Terraform.

## Initial Setup

**Account setup** — To use INWX, you need to create an account and enable multi-factor authentication (MFA) for security. This ensures that only authorized users can access the account and manage domains.

1. Sign up for an INWX account at <https://www.inwx.de/en>.
2. Enable MFA immediately after account creation:
   - Log in → Profile → Security → Two-factor authentication
   - Scan QR code with **Bitwarden Authenticator**
   - Store the TOTP seed and recovery code in **Bitwarden cloud** (not Vaultwarden)
3. Store the INWX account credentials (username and password) in **Bitwarden cloud**.

**API token setup** — To automate DNS management via Terraform, you need to create an API token in your INWX account. This token will be used by Terraform to authenticate and manage DNS records.

1. Create an API token for Terraform:
   - Log in to the INWX control panel.
   - Navigate to "API Access" → "Create API Token".
   - Select the appropriate permissions (e.g., "DNS Management") and save the token.
2. Store the API token in **Bitwarden cloud**, linked to the INWX account entry.
3. Test the API token by making a simple API call (e.g., list domains) using a tool like `curl` or Postman to ensure it works correctly.

## Domain Registration or Transfer

### Registering a New Domain

**If registering a new domain:**

1. Go to INWX (<https://www.inwx.de>) and log in to your account
2. Search for your desired domain using the search bar
3. Add it to your cart and complete the purchase
4. In INWX dashboard, verify that the **nameservers** are set to INWX defaults:
   - `ns.inwx.net`
   - `ns2.inwx.net`
   - `ns3.inwx.eu`
5. Enable **WHOIS privacy** (INWX → Domains → [your domain] → ID Protection)

### Transferring an Existing Domain

**If transferring from another registrar:**

| #   | Task                               | Notes                                                                                                                                                         |
| --- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Unlock domain at current registrar | This allows the domain to be transferred out.                                                                                                                 |
| 2   | Obtain EPP/Auth code               | This is a unique code required to authorize the transfer. It can usually be found in the domain management section of the current registrar's dashboard.      |
| 3   | Initiate transfer at INWX          | Go to INWX → Domains → Transfer domain → Enter domain name and EPP code → Follow prompts to complete the transfer process.                                    |
| 4   | Approve transfer                   | You may receive an email from the current registrar asking you to approve the transfer. Follow the instructions in the email to approve it.                   |
| 5   | Wait for transfer to complete      | Domain transfers can take anywhere from a few hours to several days to complete. You can check the status in both the current registrar and INWX dashboards.  |
| 6   | Verify transfer and update DNS     | Once the transfer is complete, verify that the domain is now listed in your INWX account. Update the nameservers to INWX defaults if not already done.        |
| 7   | Enable WHOIS privacy               | INWX → Domains → ID Protection → Enable for the transferred domain. This will protect your personal information from being publicly visible in WHOIS lookups. |

### Nameserver Configuration

Ensure all domains use the INWX nameservers:

| Nameserver | Value          |
| ---------- | -------------- |
| NS1        | `ns.inwx.net`  |
| NS2        | `ns2.inwx.net` |
| NS3        | `ns3.inwx.eu`  |
