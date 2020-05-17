#!/usr/bin/env python3

#################################################################################################
#
#   File:           main.py
#   Author:         Phil Conner
#   Description:    Transition and/or archive 410 and 411 teams inbetween semesters.
#   Notes:          There are two times during the year that this script should be run:
#                       1) At the end of a spring semester, going into fall
#                       2) At the end of a fall semester, going into spring
#
#################################################################################################

# Modules used
from configparser import ConfigParser           # to read config file
import transition_tasks                         # to process and transition teams


def main() :

    # Open configuration file
    config = ConfigParser()
    config.read('config')
    
    # Define team names to be operated on
    old_411_teams = config.get('team','old_411_teams').split(",")
    old_410_teams = config.get('team','old_410_teams').split(",")
    new_410_teams = config.get('team','new_410_teams').split(",")
    first_use_teams = config.get('team','first_use_teams').split(",")

    # Set next free uid/gid
    uidNumber = config.get('team', 'next_free_uidNumber')
    gidNumber = config.get('team', 'next_free_gidNumber')
    if uidNumber and gidNumber :
        uidNumber = int(uidNumber)
        gidNumber = int(gidNumber)
    elif not (uidNumber and gidNumber) and not first_use_teams == [''] :
        raise ValueError("uidNumber and gidNumber have not been set, but first_use_teams is non-empty! Specify values to allow creation of their AD users/groups.")

    ### TRANSITION TEAMS ###
    # Old 411 teams should be processed first -- their things need to be cleared out to make way for incoming 411 teams
    if not old_411_teams == [''] :
        for team in old_411_teams :
    	    transition_tasks.process_old_411_team(team)
    else :
        print("No old 411 teams to process, skipping!")

    # Old 410 teams should be processed second -- their things need to be cleared out to make way for incoming 410 teams
    if not old_410_teams == [''] :
        for team in old_410_teams :
    	    if team in first_use_teams :
    	        # If they were a first_use_team for 410, that means they are first_use_team for 411 too
    	        transition_tasks.process_first_use_team(team, "411", uidNumber, gidNumber)
    	        uidNumber += 1
    	        gidNumber += 1
    	    transition_tasks.process_old_410_team(team)
    else :
        print("No old 410 teams to process, skipping!")

    # New 410 teams should be processed last
    if not new_410_teams == [''] :
        for team in new_410_teams :
    	    if team in first_use_teams :
    	        transition_tasks.process_first_use_team(team, "410", uidNumber, gidNumber)
    	        uidNumber += 1
    	        gidNumber += 1
    	    transition_tasks.process_new_410_team(team)
    else :
        print("No new 410 teams to process, skipping!")

if __name__ == "__main__" :
    main()
