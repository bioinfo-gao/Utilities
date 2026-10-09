#!/usr/bin/env python3
"""Draft (NOT send) the follow-up to Wei Qi explaining the periodic reconnect + current port.
Threads under the user's already-sent reply (Sent Mail UID 207, 2026-10-08 00:12), same To/Cc as that mail.
Only APPENDs a new draft; deletes nothing."""
import imaplib, json, re, time, email
from email import policy
from email.message import EmailMessage

SUBJECT = "Re: Download instructions for your sequencing data (Athenomics)"
PORT = "21945"
BODY = f"""Dear Dr. Qi,

A short update on the server connection. Our SFTP server is reached through a relay service that reconnects automatically about every 10 to 30 hours, and each reconnection assigns a new port number. This is why the port in my earlier messages stopped working. Only the port changes; the host, username, password and folder stay the same.

  Protocol : SFTP
  Host     : bore.pub
  Port     : {PORT}   (valid until the next automatic reconnection)
  Username : client_sftp
  Password : unchanged
  Folder   : /files/Wei_Qi

What this means for your download:
  - If a transfer is interrupted, or you see "connection refused", the port has most likely changed. Please email me and I will reply with the current port.
  - The files are large, so please use a client that can resume interrupted transfers (WinSCP or FileZilla; choose "resume" when asked) rather than restarting each file.

Best regards,

Zhen Gao, PhD
Principal Bioinformatics Scientist
Athenomics
"""
assert not re.search(r"[^\x00-\x7f]", BODY), "non-ASCII char in body"
assert all(s in BODY for s in ("Zhen Gao, PhD", "Principal Bioinformatics Scientist", "Athenomics"))

cfg = json.load(open("/home/gao/.claude.json"))["mcpServers"]["gmail"]["env"]
addr, pwd = cfg["GMAIL_ADDRESS"], cfg["GMAIL_APP_PASSWORD"]
M = imaplib.IMAP4_SSL("imap.gmail.com"); M.login(addr, pwd)

M.select('"[Gmail]/Sent Mail"', readonly=True)
prev = email.message_from_bytes(M.uid("fetch", b"207", "(BODY.PEEK[HEADER])")[1][0][1], policy=policy.default)
assert str(prev["Subject"]).strip() == SUBJECT and "weqi@mgh.harvard.edu" in str(prev["To"]), prev["Subject"]

msg = EmailMessage()
msg["From"], msg["To"], msg["Subject"] = addr, prev["To"], SUBJECT
msg["In-Reply-To"] = prev["Message-ID"]
msg["References"] = ((prev["References"] + " ") if prev["References"] else "") + prev["Message-ID"]
msg.set_content(BODY)

def n():
    M.select('"[Gmail]/Drafts"'); return len(M.uid("search", None, "ALL")[1][0].split())
before = n()
M.append('"[Gmail]/Drafts"', r"(\Draft)", imaplib.Time2Internaldate(time.time()), bytes(msg))
after = n()
print("Drafts before/after:", before, after)
assert after == before + 1
uid = M.uid("search", None, "ALL")[1][0].split()[-1]
chk = email.message_from_bytes(M.uid("fetch", uid, "(RFC822)")[1][0][1], policy=policy.default)
got = chk.get_body(("plain",)).get_content().replace("\r\n", "\n")
assert got.strip() == BODY.strip(), "readback mismatch"
print("readback OK | To:", chk["To"], "| Subject:", chk["Subject"], "| In-Reply-To:", chk["In-Reply-To"])
M.logout()
