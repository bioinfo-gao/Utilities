#!/usr/bin/env python3
"""Add the observed reconnect times to my Wei Qi draft. FETCH current draft body -> exact-once replace ->
APPEND new -> read back -> only then delete the previous version of this same draft. Draft only, never sent."""
import imaplib, json, re, time, email
from email import policy
from email.message import EmailMessage

SUBJECT = "Re: Download instructions for your sequencing data (Athenomics)"
ANCHOR = "This is why the port in my earlier messages stopped working."
ADD = (ANCHOR + " The reconnections we have recorded so far (US Eastern time) were on "
       "October 7 at 09:53 (port changed from 8163 to 24279) and on October 8 at 17:54 "
       "(port changed from 24279 to 21945).")

cfg = json.load(open("/home/gao/.claude.json"))["mcpServers"]["gmail"]["env"]
M = imaplib.IMAP4_SSL("imap.gmail.com"); M.login(cfg["GMAIL_ADDRESS"], cfg["GMAIL_APP_PASSWORD"])

def drafts():
    M.select('"[Gmail]/Drafts"')
    out = {}
    for u in M.uid("search", None, "ALL")[1][0].split():
        out[u] = email.message_from_bytes(M.uid("fetch", u, "(BODY.PEEK[HEADER])")[1][0][1], policy=policy.default)
    return out

before = drafts()
old = [u for u, m in before.items() if str(m["Subject"]).strip() == SUBJECT and "weqi@mgh.harvard.edu" in str(m["To"])]
print("drafts before:", len(before), "| target draft UIDs:", old)
assert len(old) == 1
raw = M.uid("fetch", old[0], "(RFC822)")[1][0][1]
orig = email.message_from_bytes(raw, policy=policy.default)
body = orig.get_body(("plain",)).get_content().replace("\r\n", "\n")
assert body.count(ANCHOR) == 1 and "October 7" not in body
new_body = body.replace(ANCHOR, ADD)
assert new_body.count("October 7 at 09:53") == 1 and new_body != body
assert not re.search(r"[^\x00-\x7f]", new_body)
assert all(s in new_body for s in ("Zhen Gao, PhD", "Principal Bioinformatics Scientist", "Athenomics"))

msg = EmailMessage()
for h in ("From", "To", "Cc", "Subject", "In-Reply-To", "References"):
    if orig[h]: msg[h] = orig[h]
msg.set_content(new_body)
M.append('"[Gmail]/Drafts"', r"(\Draft)", imaplib.Time2Internaldate(time.time()), bytes(msg))
after = drafts()
new = [u for u in after if u not in before]
assert len(new) == 1, new
chk = email.message_from_bytes(M.uid("fetch", new[0], "(RFC822)")[1][0][1], policy=policy.default)
assert chk.get_body(("plain",)).get_content().replace("\r\n", "\n").strip() == new_body.strip(), "readback mismatch"
print("new UID", new[0], "readback OK | To:", chk["To"], "| In-Reply-To:", chk["In-Reply-To"])
M.uid("store", old[0], "+FLAGS", r"(\Deleted)"); M.expunge()
final = drafts()
print("drafts now:", len(final), "| target drafts:", [u for u, m in final.items() if str(m["Subject"]).strip() == SUBJECT])
M.logout()
