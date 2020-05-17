#################################################################################################
#
#   File:           bash_tasks.py
#   Author:         Phil Conner
#   Description:    Perform tasks in bash necessary to transition/archive team directories.
#
#################################################################################################


# Modules used
import subprocess           # to run bash commands
import os                   # to check if directories exist, for repeatability


# Make new home directory, and copy over old files if copy_old_files is set to True
def make_new_homedir(new_homedir, team_string, copy_old_files=False, old_homedir="") :

    # Create new home directory if it doesn't exist yet
    print("  Creating new home directory...")
    if not os.path.isdir("{}".format(new_homedir)) :
        subprocess.check_output("mkdir -p {}".format(new_homedir), shell=True)
        # Copy files from old home directory to new home directory, since this is a newly created directory
        if copy_old_files :
            print("  Copying over old files...")
            if os.path.isdir("{}".format(old_homedir)) :
                subprocess.check_output("cp -rp {}/. {}".format(old_homedir, new_homedir), shell=True)
            else :
                print("    Old home directory doesn't exist, operation skipped!")
    else :
        print("    New home directory already exists, operation skipped!")
    
    # Set permissions of new home directory
    print("  Setting permissions and ownership...")
    subprocess.check_output("chmod 755 {}".format(new_homedir), shell=True)
    
    # Set ownership of new home directory
    subprocess.check_output("chown -R {}:{} {}".format(team_string, team_string, new_homedir), shell=True)


# Archive a team's old web directory
def archive_webdir(old_homedir, old_cpi_webdir) :
    
    # Create cpi web directory for archived web content if it doesn't exist yet, and copy over old web content
    if not os.path.isdir("{}".format(old_cpi_webdir)) :
        if os.path.isdir("{}/secure_html".format(old_homedir)) :
            print("  Creating archive web directory...")
            subprocess.check_output("mkdir -p {}".format(old_cpi_webdir), shell=True)
            print("  Copying over old web content...")
            subprocess.check_output("cp -rp {}/secure_html/. {}".format(old_homedir, old_cpi_webdir), shell=True)
        elif os.path.isdir("{}/public_html".format(old_homedir)) :
            print("  Creating archive web directory...")
            subprocess.check_output("mkdir -p {}".format(old_cpi_webdir), shell=True)
            print("  Copying over old web content...")
            subprocess.check_output("cp -rp {}/public_html/. {}".format(old_homedir, old_cpi_webdir), shell=True)
        else :
            print("  No public_html or secure_html found in home directory, operation skipped!")
            return 1
    else :
        print("  Archived web directory already exists.")
    
    # Set permissions of cpi web archive directory
    print("  Setting permissions and ownership...")
    subprocess.check_output("chmod 755 {}".format(old_cpi_webdir), shell=True)
    
    # Set ownership of cpi web archive directory
    subprocess.check_output("chown -R redacted:redacted {}".format(old_cpi_webdir), shell=True)
