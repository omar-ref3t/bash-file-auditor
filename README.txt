Bash File Auditor & Backup Tool

Requires Bash (available by default on Linux).

Project work: Bash menu, audit and backup functions, command-line actions, and sample data.

How to run (from this project folder):
  chmod +x auditor.sh lib.sh sample_data/run_me.sh
  chmod 000 sample_data/secret.dat
  ./auditor.sh sample_data

Run a single action:
  ./auditor.sh sample_data scan
  ./auditor.sh sample_data perms
  ./auditor.sh sample_data ext
  ./auditor.sh sample_data backup

The menu also provides file-name search, backup listing, and backup restore.
Backups are created inside sample_data/backups. The activity log is auditor.log.
The sample includes run_me.sh as an executable file and secret.dat with no permissions.
