# Chat protocol v1: design and limits

The implementation uses native Web Crypto primitives, not an independently audited messaging protocol. No audit or formal verification is claimed. Interactive browser/device testing remains outstanding.

## Keys and ciphertext

Each account creates an ECDH P-256 encryption key pair and an ECDSA P-256 signing key pair on its client. The public directory is immutable through the API. The private JWK bundle is encrypted with AES-256-GCM under a randomly generated 256-bit recovery secret. Only the encrypted vault and public keys reach the server. The recovery secret is independent of the Supabase login password and is not sent in plaintext to the server.

Each message uses a fresh random 256-bit AES-GCM content key and 96-bit nonce. The content key is separately encrypted for both participants using ephemeral ECDH P-256, HKDF-SHA-256 and AES-GCM. HKDF and AEAD bind the protocol, recipient key fingerprint, sender, conversation and random message ID. The complete envelope is signed with the sender's ECDSA signing key. The receiving client verifies the expected sender/conversation/message binding and signature before decrypting. Clients pin public-key fingerprints locally; security codes can be compared out of band.

Primitives reference: W3C Web Cryptography API, https://www.w3.org/TR/WebCryptoAPI/ . Canonical JSON sorts object keys recursively. No custom arithmetic or random-number generator is used.

The design intentionally allows full history recovery. It does not implement a Double Ratchet, forward secrecy or post-compromise recovery. Possession of an account's recovery secret or private keys allows decryption of retained messages for that account. Deleting expired active records does not revoke copies retained by participants, in backups, or in an earlier report. Treat a lost/compromised key or device as a security incident; there is no automatic secure key rotation or remote erasure in this release.

## Devices

The local recovery secret is AES-GCM encrypted under a nonextractable Web Crypto key stored in IndexedDB. A new device creates a nonextractable ECDH private key and submits only its public key. An already unlocked device, after explicit code comparison, seals the recovery secret to that device. Alternatively a user enters the offline recovery secret. A server-side device approval alone without a valid encrypted grant cannot recover private keys.

This protects against passive database disclosure; it does not protect against malware, a compromised browser profile, XSS or malicious JavaScript served by the site. A website operator able to replace client code or manipulate the first public-key discovery can attack a web E2EE client. Local pinning and out-of-band comparison provide continuity checks, not a global key-transparency service. The server remains trusted for account authorization and metadata such as delivery order, expiry and timestamps.

Approved-device removal is not represented as cryptographic revocation. Only pending device requests can be cancelled through the API. Local forgetting removes that browser's cached keys, not remote copies of previously disclosed keys.

## Reports

After the reporting participant separately confirms full-history disclosure, the server snapshots all currently retained ciphertext in that conversation (including messages hidden from that participant's normal view). The reporting client verifies each original signature and extracts each snapshot message's independent content key. It encrypts the message-ID/key map, report reason and explanation to the Admin's public key and signs that packet.

The server stores the original ciphertext snapshot and encrypted report packet. It never receives the plaintext history or plaintext report key map. The Admin decrypts the report packet, verifies original message signatures and decrypts each snapshot message independently. Original account/private keys are never shared with the Admin; a report grants no access to future messages or unrelated conversations. A malicious reporter can submit incomplete/invalid evidence; the Admin client rejects missing keys, invalid signatures or failed AEAD authentication rather than displaying unverified text. The server is trusted for membership and attribution metadata; signatures are checked against the account key directory snapshot.

## Authorization and records

All chat tables are in the private schema with RLS and revoked API-role privileges. Only `public.pull_chat` is callable by authenticated clients. It is an invoker wrapper for one private, fixed-search-path definer entry point. The entry point checks the actual `auth.uid()`, current profile approval, username, active rule consent and eligibility. Internal invoker helpers cannot be called by API roles. The exact owner account may inspect consent records and submitted reports, but has no membership bypass for ordinary chat history.

Consent rows are unique per account and rule version, use a server timestamp and are not updated by repeat acceptance. Rule versions are retained. Read receipts persist only an ordered read watermark, never an application-level read-at timestamp. Transport/service logs and other metadata are outside the E2EE content guarantee.

Retention agreement is serialized and version checked. The recipient must confirm another participant's proposal. Each new message gets its own server-generated expiry; existing messages are unchanged. The API purges expired active records on calls and a cron job purges every minute. Report snapshots are retained for moderation. Browser copies and external exports cannot be remotely deleted.

## Verification still required

Before describing the system as security-audited, obtain independent review of the protocol, key lifecycle, client rendering, CSP/hosting configuration and report attribution. Test actual desktop/mobile browsers, reload, sign-out, password reset, device approval and recovery, concurrent tabs, tampered directory keys, expired messages and reporting in the deployed environment. Automated tests cover cryptographic round trips/tampering, recovery/grants, authorization, retention, report snapshots and collection-data isolation; they do not replace that review.
