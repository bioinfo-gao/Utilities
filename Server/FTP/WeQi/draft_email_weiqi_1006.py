#!/usr/bin/env python3
"""Draft (NOT send) the sFTP download-instructions email to Wei Qi, via IMAP APPEND to Gmail Drafts."""
import imaplib, json, re, time
from email.message import EmailMessage

TO = "weqi@mgh.harvard.edu"
SUBJECT = "Download instructions for your sequencing data (Athenomics)"
BODY = """Dear Dr. Qi,

Your sequencing data are ready for download from our secure SFTP server. The data set contains 46 data files (10 sample folders, numbered 1 to 10) plus one checksum file, MD5.csv; the total size is about 992 GB.

Connection details
  Protocol : SFTP (not FTP or FTPS)
  Host     : bore.pub
  Port     : 38643
  Username : client_sftp
  Password : will be sent to you in a separate message
  Folder   : after logging in, open /files/Wei_Qi (the root folder itself is read-only)

How to download
  1. Install an SFTP client such as WinSCP, FileZilla or Cyberduck.
  2. Create a new connection with the details above, and log in.
  3. Go to /files/Wei_Qi and copy the folders 1-10 and MD5.csv to your computer.
  4. For a transfer this large we recommend a wired network and a client that can resume interrupted transfers (WinSCP and FileZilla both can). On a command line, "sftp -P 38643 client_sftp@bore.pub" followed by "get -r /files/Wei_Qi" works as well.

Checking the files
MD5.csv lists the MD5 checksum of every file. After downloading you can compare it with the checksum computed on your side (Windows: certutil -hashfile <file> MD5; macOS/Linux: md5sum <file>). Matching values confirm that the file arrived intact.

Please make sure you have at least 1 TB of free disk space before starting. If the connection fails at any point, or the port does not respond, just let me know and I will check the server and send you the current details.

Best regards,

Zhen Gao, PhD
Principal Bioinformatics Scientist
Athenomics
"""
assert not re.search(r"[^\x00-\x7f]", BODY), "non-ASCII char in body"

cfg = json.load(open("/home/gao/.claude.json"))["mcpServers"]["gmail"]["env"]
addr, pwd = cfg["GMAIL_ADDRESS"], cfg["GMAIL_APP_PASSWORD"]
msg = EmailMessage()
msg["From"], msg["To"], msg["Subject"] = addr, TO, SUBJECT
msg.set_content(BODY)

M = imaplib.IMAP4_SSL("imap.gmail.com"); M.login(addr, pwd)
def n():
    typ, d = M.select('"[Gmail]/Drafts"'); return int(d[0])
before = n()
M.append('"[Gmail]/Drafts"', r"(\Draft)", imaplib.Time2Internaldate(time.time()), bytes(msg))
after = n()
print("Drafts before/after:", before, after)
assert after == before + 1
M.logout()
