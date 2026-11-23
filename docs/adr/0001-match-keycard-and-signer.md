# ADR-0001: The Keystore app matches the Keycard and Signer apps

- Status: Accepted
- Date: 2026-11-23
- Scope: QML only

## Decision
- Layout: a full-width title row (title, (i), subtitle, as in Signer) over a 560 px centred column.
- One primary action per state: Add accounts on each wallet card; Unlock while locked; Create wallet
  in the empty state. Create and Import are secondary otherwise. While a wallet is locked the banner
  is the whole message (no second empty state).
- The wallet card and account rows are the Keycard app's (`accountkit/WalletCard.qml`,
  `AccountDetails.qml`): rename pencil beside the name, trash on the right, account rows as tiles,
  Add accounts as the card's full-width button. Other actions are icons with the label as tooltip
  (Export, Change password). An Ethereum row drops "account N": the path carries the index.
- Change password uses the password icon from Status (StatusQ, MPL-2.0).
- A kept recovery phrase shows as the numbered word table.

## Consequences
The three key apps read alike. Verified by hand on Basecamp 0.3.2.
