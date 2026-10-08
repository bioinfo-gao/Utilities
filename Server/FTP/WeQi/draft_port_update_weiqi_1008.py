#!/usr/bin/env python3
"""Draft (NOT send) a short port-update reply to Wei Qi, threaded under the sent download-instructions email.
Aborts without writing if the original email is not found in Sent Mail."""
import imaplib, json, re, time, email
from email import policy
from email.message import EmailMessage

TO = "weqi@mgh.harvard.edu"
ORIG_SUBJECT = "Download instructions for your sequencing data (Athenomics)"
NEW_PORT = "24279"
BODY = f"""Dear Dr. Qi,

The server connection details have changed since my previous message. Please use the new port below; everything else stays the same.

  Protocol : SFTP
  Host     : bore.pub
  Port     : {NEW_PORT}   (previously 8163, which no longer works)
  Username : client_sftp
  Password : unchanged
  Folder   : /files/Wei_Qi

If you see "connection refused" again, please let me know and I will send you the current port right away.

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
sent = M.uid("search", None, "TO", TO, "SUBJECT", f'"{ORIG_SUBJECT}"')[1][0].split()
print("sent copies of original:", sent)
assert sent, "original email not found in Sent Mail -> not writing a reply"
o = email.message_from_bytes(M.uid("fetch", sent[-1], "(BODY.PEEK[HEADER])")[1][0][1], policy=policy.default)
mid, refs = o["Message-ID"], o["References"]

msg = EmailMessage()
msg["From"], msg["To"], msg["Subject"] = addr, TO, "Re: " + ORIG_SUBJECT
msg["In-Reply-To"] = mid
msg["References"] = ((refs + " ") if refs else "") + mid
msg.set_content(BODY)

M.select('"[Gmail]/Drafts"')
before = len(M.uid("search", None, "ALL")[1][0].split())
M.append('"[Gmail]/Drafts"', r"(\Draft)", imaplib.Time2Internaldate(time.time()), bytes(msg))
M.select('"[Gmail]/Drafts"')
after = len(M.uid("search", None, "ALL")[1][0].split())
print("Drafts before/after:", before, after)
assert after == before + 1
M.logout()
