#################################################################################################
#
#   File:           transition_tasks.py
#   Author:         Phil Conner
#   Description:    Perform tasks necessary to transition a team of a certain type.
#
#################################################################################################

# Modules used
from configparser import ConfigParser               # to read config file
import bash_tasks                                   # to operate on team home directories
import ad_tasks                                     # to move group members, reset passwords, and change autofs stuff

# Open configuration file
config = ConfigParser()
config.read('config')

# Set new and old semester from config file (Ex: "s19" and "f19")
new_semester = config.get('semester','new_semester')
old_semester = config.get('semester','old_semester')

################################################################################################################

def process_old_411_team(team) :
    
    print("\n------------------------------------------------")
    print("Currently processing old 411 team: " + team)
    print("------------------------------------------------")

    ## Team strings ##
    # Old semester team string (Ex: "reds19")
    old_team_string = team + old_semester
    # 411 team string (Ex: "411red")
    _411_team_string = "411" + team
    
    ## Directories ##
    # Old home directory
    old_homedir = config.get('path', 'cpi_base_path') + "/411/" + old_team_string
    # CPI web directories for old 410/411 projects
    old_cpi_webdir = config.get('path', 'cpi_base_web_path') + "/411/" + old_team_string


    ## TRANSITION ##
    # Archive web directory
    print("Archiving web directory...")
    bash_tasks.archive_webdir(old_homedir, old_cpi_webdir)
    # Clear team's group in AD
    print("Emptying AD group...")
    ad_tasks.empty_group(_411_team_string)

    print("Done.")

################################################################################################################

def process_old_410_team(team) :

    print("\n------------------------------------------------")
    print("Currently processing old 410 team: " + team)
    print("------------------------------------------------")

    ## Team strings ##
    # New and old semester team strings (Ex: "reds19" and "redf19)
    new_team_string = team + new_semester
    old_team_string = team + old_semester
    # 410 and 411 team strings (Ex: "410red" and "411red")
    _410_team_string = "410" + team
    _411_team_string = "411" + team
    
    ## Directories ##
    # Old home directory
    old_410_homedir = config.get('path', 'cpi_base_path') + "/410/" + old_team_string
    # New home directory
    new_411_homedir = config.get('path', 'cpi_base_path') + "/411/" + new_team_string
    # CPI web directories for old 410/411 projects
    old_410_cpi_webdir = config.get('path', 'cpi_base_web_path') + "/410/" + old_team_string

    ## Network paths (AD) ##
    # Home directory UNC paths
    new_411_ad_homedir = config.get('path', 'cpi_base_ad_homedir') + "\\411\\" + new_team_string
    # Map entries
    new_411_mapentry = config.get('path', 'cpi_base_mapentry') + "/411/" + new_team_string


    ## TRANSITION ##
    # Archive web directory
    print("Archiving web directory...")
    bash_tasks.archive_webdir(old_410_homedir, old_410_cpi_webdir)
    # Create new 411 directory, copy over files from old 410 directory
    print("Making new 411 directory and copying over old files...")
    bash_tasks.make_new_homedir(new_411_homedir, _411_team_string, copy_old_files=True, old_homedir=old_410_homedir)
    # Add members of 410 group to corresponding 411 group in AD
    print("Moving AD members from 410 group to corresponding 411 group...")
    ad_tasks.move_410_group_members(team, _410_team_string, _411_team_string)
    # Empty team's 410 group in AD
    print("Emptying 410 AD group...")
    ad_tasks.empty_group(_410_team_string)
    # Change homeDirectory attribute of team's 411 class account
    print("Changing homeDirectory attribute of 411 class account...")
    ad_tasks.change_user_homedir(_411_team_string, new_411_ad_homedir)
    # Change nisMapEntry of 411 nisObject
    print("Changing nisMapEntry of 411 nisObject...")
    ad_tasks.change_mapentry(_411_team_string, new_411_mapentry)
    # Change password of 411 class account
    print("Changing password of 411 class account...")
    passwd = ad_tasks.get_random_passwd(10)
    ad_tasks.change_user_passwd(_411_team_string, passwd)

    print("Done.")

################################################################################################################

def process_new_410_team(team) :

    print("\n------------------------------------------------")
    print("Currently processing new 410 team: " + team)
    print("------------------------------------------------")

    ## Team strings ##
    # New semester team string (Ex: "redf19)
    new_team_string = team + new_semester
    # 410 team string (Ex: "410red")
    _410_team_string = "410" + team
    
    ## Directories ##
    # New home directories
    new_410_homedir = config.get('path', 'cpi_base_path') + "/410/" + new_team_string

    ## Network paths (AD) ##
    # Home directory UNC paths
    new_410_ad_homedir = config.get('path', 'cpi_base_ad_homedir') + "\\410\\" + new_team_string
    # Map entries
    new_410_mapentry = config.get('path', 'cpi_base_mapentry') + "/410/" + new_team_string


    ## TRANSITION ##
    # Create new 410 directory
    print("Making new 410 directory...")
    bash_tasks.make_new_homedir(new_410_homedir, _410_team_string)
    # Change homeDirectory attribute of team's 410 class account
    print("Changing homeDirectory attribute of 410 class account...")
    ad_tasks.change_user_homedir(_410_team_string, new_410_ad_homedir)
    # Change nisMapEntry of 410 nisObject
    print("Changing nisMapEntry of 410 nisObject...")
    ad_tasks.change_mapentry(_410_team_string, new_410_mapentry)
    # Change password of 410 class account
    print("Changing password of 410 class account...")
    passwd = ad_tasks.get_random_passwd(10)
    ad_tasks.change_user_passwd(_410_team_string, passwd)

    print("Done.")

################################################################################################################

def process_first_use_team(team, class_num, uidNumber, gidNumber) :
    
    print("\n------------------------------------------------")
    print("Currently setting up first use team: " + class_num + team)
    print("------------------------------------------------")

    # Team string (Ex: "410red")
    team_string = class_num + team

    ## INITIAL SETUP ##
    # Create team account
    print("Creating team account...")
    ad_tasks.create_team_account(team_string, uidNumber, gidNumber)  

    # Create team group
    print("Creating team group...")
    ad_tasks.create_team_group(team_string, gidNumber)

    # Create team nisObject
    print("Creating team nisObject...")
    ad_tasks.create_team_nisObject(team_string, new_semester)

    print("Done.")
