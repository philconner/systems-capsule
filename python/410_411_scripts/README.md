### Files  
- `main.py` - Main executable, calls functions from `transition_tasks.py`.  
- `transition_tasks.py` - Functions to transition a team, calls functions from `ad_tasks.py` and `bash_tasks.py`.  
- `ad_tasks.py` - Functions for modifying team objects in AD.
- `bash_tasks.py` - Functions for modifying/archiving team directories.
- `config` - Config file.
  
### How to run  
Run as `python3 -u main.py` so you can see what's happening. Also, don't put spaces in-between commas in the config file.

Temporary passwords for each team's AD user will be written to a file in the current directory named 'passwords.txt'.
