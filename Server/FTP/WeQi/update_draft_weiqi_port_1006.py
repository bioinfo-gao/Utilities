#!/usr/bin/env python3
"""Replace sFTP port 38643 -> 8163 in the existing Wei Qi Gmail draft (FETCH, exact-once replace, APPEND new, verify, then delete old)."""
import imaplib, json, re, time, email
from email import policy
from email.message import EmailMessage

SUBJECT = "Download instructions for your sequencing data (Athenomics)"
OLD, NEW = "38643", "8163"
SIGNATURE = ("Zhen Gao, PhD", "Principal Bioinformatics Scientist", "Athenomics")  # Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics
cfg = json.load(open("/home/gao/.claude.json"))["mcpServers"]["gmail"]["env"]
M = imaplib.IMAP4_SSL("imap.gmail.com"); M.login(cfg["GMAIL_ADDRESS"], cfg["GMAIL_APP_PASSWORD"])
M.select('"[Gmail]/Drafts"')
typ, d = M.uid("search", None, "SUBJECT", f'"{SUBJECT}"')
uids = d[0].split(); print("matching draft UIDs:", uids)
assert len(uids) == 1, "expected exactly one draft"
old_uid = uids[0]
raw = M.uid("fetch", old_uid, "(RFC822)")[1][0][1]
orig = email.message_from_bytes(raw, policy=policy.default)
body = orig.get_body(("plain",)).get_content().replace("\r\n", "\n")
assert body.count(OLD) == 2, body.count(OLD)
assert "Port     : 38643" in body and 'sftp -P 38643 client_sftp@bore.pub' in body
new_body = body.replace("Port     : 38643", "Port     : 8163").replace("sftp -P 38643 ", "sftp -P 8163 ")
assert OLD not in new_body and new_body.count(NEW) == 2
assert all(s in new_body for s in SIGNATURE), "signature missing"
assert not re.search(r"[^\x00-\x7f]", new_body)

msg = EmailMessage()
for h in ("From", "To", "Cc", "Subject"):
    if orig[h]: msg[h] = orig[h]
msg.set_content(new_body)
M.append('"[Gmail]/Drafts"', r"(\Draft)", imaplib.Time2Internaldate(time.time()), bytes(msg))
M.select('"[Gmail]/Drafts"')
uids2 = M.uid("search", None, "SUBJECT", f'"{SUBJECT}"')[1][0].split()
new_uid = [u for u in uids2 if u != old_uid]
assert len(new_uid) == 1, uids2
chk = email.message_from_bytes(M.uid("fetch", new_uid[0], "(RFC822)")[1][0][1], policy=policy.default)
got = chk.get_body(("plain",)).get_content().replace("\r\n", "\n").strip()
assert got == new_body.strip(), "readback mismatch"
print("new draft UID", new_uid[0], "readback OK; To:", chk["To"], "Subject:", chk["Subject"])
M.uid("store", old_uid, "+FLAGS", r"(\Deleted)"); M.expunge()
M.select('"[Gmail]/Drafts"')
print("Drafts count now:", len(M.uid("search", None, "ALL")[1][0].split()),
      "| matching:", M.uid("search", None, "SUBJECT", f'"{SUBJECT}"')[1][0].split())
M.logout()
