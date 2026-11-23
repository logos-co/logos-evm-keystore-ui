# ADR-0002: Create wallet is a four-step flow, and the phrase hides until asked for

- Status: Accepted
- Date: 2026-11-23
- Scope: `AccountFlowSheet.qml`

## Context
Create showed a new recovery phrase the moment it opened, and asked for words 1, 5 and the last
in one field. Choosing, naming and the password shared one long screen, with a non-DS dropdown.

## Decision
The Keycard app's add flow, step for step: a centred "Step N of 4" header and one concern a step.
1. Recovery phrase: a warning and Show recovery phrase first; then the words; then three random
   words typed back, each checked as it is left.
2. Choose accounts: Ethereum / Bitcoin as radio buttons, tappable account tiles, paging.
3. Name them: the wallet's name and one block per account.
4. Set a password, with the optional encrypted recovery source.
Cancel on the first step, Back after; the forward action is the primary button.

## Consequences
No phrase is on screen before the person chooses to see it, and the backup check can't be passed
by remembering a fixed pattern. Verified by hand: a full create to saved accounts.
