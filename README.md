ASN Blocker
===========

Script to block an entire AS by rejecting traffic on the FORWARD chain of your firewall or router.


Usage
---
```
asnblocker.sh domain_to_block.com
```


All the issued iptables commands are logged onto a script_path/script_name.log.
On succesful execution prints the command to revert all changes and instructions to unblock some hosts if needed.
