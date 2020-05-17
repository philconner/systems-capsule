#################################################################################################
#
#   File:           ad_tasks.py
#   Author:         Phil Conner
#   Description:    Perform tasks in AD necessary to transition 410/411 teams.
#
#################################################################################################

# Modules used
import random                                                                                   # to generate temp passwords
import string                                                                                   # to generate temp passwords
from ldap3 import Server, Connection, ALL, NTLM, MODIFY_DELETE, MODIFY_ADD, MODIFY_REPLACE      # to operate on AD objects

# Active directory connection
server_info = Server('redacted.redacted.redacted', get_info=ALL, use_ssl=True)
ldap_connection = Connection(server_info, user="redacted\\redacted", password='redacted', authentication=NTLM, auto_bind=True)

###########################################################################################################################################

## Return a random password ##
def get_random_passwd(length) :

    char_pools = [string.ascii_lowercase, string.ascii_uppercase, string.digits, "!@$%"]
    char_string = "".join(char_pools)
    passwd = ""

    # Need one of each for complexity requirements
    for char_pool in char_pools :
        passwd += random.choice(char_pool)

    # Fill the rest in to meet specified length
    passwd += "".join(random.sample(char_string, length - 4))

    return passwd


###########################################################################################################################################

## Empty a team's group in AD  ##
def empty_group(team_string) :
    
    # Search for group
    group_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                               search_filter = '(&(objectClass=group)(cn={}))'.format(team_string),
                                               search_scope = 'SUBTREE',
                                               attributes = ['member', 'distinguishedName'])
    
    # Check if no group found
    if not group_search :
        print("  AD group not found for team " + team_string + ", operation skipped!")
        return 1
    # Check for more than one entry not needed since its an exact search

    group_dn = ldap_connection.entries[0].distinguishedName[0]

    # Remove members
    for value in ldap_connection.entries[0].member.values :
        if not value.startswith('CN=41') :
            ldap_connection.modify(group_dn, {'member': [(MODIFY_DELETE, [value])]})

###########################################################################################################################################

## Add members from 410 group to 411 group in AD  ##
def move_410_group_members(team, _410_team_string, _411_team_string) :

    # Search for both groups
    groups_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                           search_filter = '(&(objectClass=group)(cn=*{}))'.format(team),
                                           search_scope = 'SUBTREE',
                                           attributes = ['member', 'distinguishedName'])
    
    # Check if less than 2 groups found
    if len(ldap_connection.entries) < 2 :
        print("  Less than 2 AD groups found for team " + team + ", operation skipped!")
        return 1
    # Check for more than 2 groups found
    elif len(ldap_connection.entries) > 2 :
        print("  More than 2 AD groups found for team " + team + ", operation skipped!")
        return 1

    # Determine which group is the source and which is destination. The 410 group should always be the first entry, but doing this to be safe
    for entry in ldap_connection.entries :
        if(entry.distinguishedName[0].startswith('CN=410')) :
            _410_group = entry
        elif(entry.distinguishedName[0].startswith('CN=411')) :
            _411_group = entry

    # Group DNs
    _410_group_dn = _410_group.distinguishedName[0]
    _411_group_dn = _411_group.distinguishedName[0]

    # Add members from 410 group to 411 group
    for value in _410_group.member.values :
        if not value.startswith('CN=410') :
            ldap_connection.modify(_411_group_dn, {'member': [(MODIFY_ADD, [value])]})

###########################################################################################################################################

## Change homeDirectory of a team's class account ##
def change_user_homedir(team_string, ad_homedir) :

    # Some class accounts are "<class_number><team>", while others are "<class_number> <team>", therefore need to slice team_string into those separate values for the search
    class_number = team_string[:3]
    team = team_string[3:]
    
    # Search for class account
    account_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                            search_filter = '(&(objectClass=user)(cn={}*{}))'.format(class_number, team),
                                            search_scope = 'SUBTREE',
                                            attributes = ['homeDirectory', 'distinguishedName'])

    # Check if no account found
    if not account_search :
        print("  No AD class account found for team " + team_string + ", operation skipped!")
        return 1
    # Check if more than one account found
    elif len(ldap_connection.entries) > 1 :
        print("  More than one AD class account found for team " + team_string + ", operation skipped!")
        return 1 

    account_dn = ldap_connection.entries[0].distinguishedName[0]

    # Change homeDirectory attribute for new semester
    ldap_connection.modify(account_dn, {'homeDirectory': [(MODIFY_REPLACE, [ad_homedir])]})

###########################################################################################################################################

## Change nisMapEntry of a team's nisObject ##
def change_mapentry(team_string, mapentry) :

    # Search for nisObject
    nisobject_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                              search_filter = '(&(objectClass=nisObject)(cn={}))'.format(team_string),
                                              search_scope = 'SUBTREE',
                                              attributes = ['nisMapEntry', 'distinguishedName'])

    # Check if no nisObject found
    if not nisobject_search :
        print("  No AD nisObject found for team " + team_string + ", operation skipped!")
        return 1
    # Check for more than one entry not needed since its an exact search

    nisobject_dn = ldap_connection.entries[0].distinguishedName[0]

    # Change nisMapEntry attribute for new semester
    ldap_connection.modify(nisobject_dn, {'nisMapEntry': [(MODIFY_REPLACE, [mapentry])]})

###########################################################################################################################################

## Change password of a team's class account  ##
def change_user_passwd(team_string, passwd) :

    # Some class accounts are "<class_number><team>", while others are "<class_number> <team>", therefore need to slice team_string into those separate values for the search
    class_number = team_string[:3]
    team = team_string[3:]

    # Search for class account
    account_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                            search_filter = '(&(objectClass=user)(cn={}*{}))'.format(class_number, team),
                                            search_scope = 'SUBTREE',
                                            attributes = ['distinguishedName'])

    # Check if no account found
    if not account_search :
        print("  No AD class account found for team " + team_string + ", operation skipped!")
        return 1
    # Check if more than one account found
    elif len(ldap_connection.entries) > 1 :
        print("  More than one AD class account found for team " + team_string + ", operation skipped!")
        return 1

    account_dn = ldap_connection.entries[0].distinguishedName[0]

    # Change password
    ldap_connection.extend.microsoft.modify_password(account_dn, passwd)
    with open("passwords.txt", 'a+') as passwd_file :
        passwd_file.write("{:<20}{}\n".format(team_string, passwd))

###########################################################################################################################################

def create_team_account(team_string, uidNumber, gidNumber) :

    class_number = team_string[:3]
    team = team_string[3:]

    # Make sure it doesn't exist
    account_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                            search_filter = '(&(objectClass=user)(cn={}))'.format(team_string),
                                            search_scope = 'SUBTREE',
                                            attributes = ['distinguishedName'])
    if account_search :
        print("  Team account already exists, operation skipped!")
        return 1

    account_dn = "cn={},ou=redacted,dc=redacted,dc=redacted,dc=redacted".format(team_string)

    # Create account
    ldap_connection.add(account_dn,
                        ['top','person','organizationalPerson','user'],
                        {'uidNumber' : '{}'.format(uidNumber), 
                         'gidNumber' : '{}'.format(gidNumber),
                         'homeDrive' : 'Z:',
                         'sAMAccountName' : '{}'.format(team_string),
                         'displayName' : '{} {}'.format(class_number, team),
                         'userPrincipalName' : '{}@redacted.redacted.redacted'.format(team_string),
                         'unixHomeDirectory' : '/home/{}'.format(team_string),
                         'loginShell' : '/usr/local/bin/bash'})

    # Set password -- should be overwritten afterwards, this is just so the account can be enabled
    passwd = get_random_passwd(10)
    ldap_connection.extend.microsoft.modify_password(account_dn, passwd)
 
    # Enable account
    ldap_connection.modify(account_dn, {'userAccountControl' : [('MODIFY_REPLACE', 512)]})

###########################################################################################################################################

def create_team_group(team_string, gidNumber) :
    
    # Make sure it doesn't exist
    group_search = ldap_connection.search(search_base = 'ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                            search_filter = '(&(objectClass=group)(cn={}))'.format(team_string),
                                            search_scope = 'SUBTREE',
                                            attributes = ['distinguishedName'])

    if group_search :
        print("  Team group already exists, operation skipped!")
        return 1

    group_dn = "cn={},ou=redacted,dc=redacted,dc=redacted,dc=redacted".format(team_string)

    # Create group
    ldap_connection.add(group_dn,
                        ['top','group'],
                        {'gidNumber' : '{}'.format(gidNumber),
                         'sAMAccountName' : 'U_{}'.format(team_string),
                         'displayName' : '{}'.format(team_string),
                         'member' : 'cn={},ou=redacted,dc=redacted,dc=redacted,dc=redacted'.format(team_string)})

###########################################################################################################################################

def create_team_nisObject(team_string, semester) :
    
    # Make sure it doesn't exist
    nisObject_search = ldap_connection.search(search_base = 'cn=redacted,ou=redacted,dc=redacted,dc=redacted,dc=redacted',
                                            search_filter = '(&(objectClass=nisObject)(cn={}))'.format(team_string),
                                            search_scope = 'SUBTREE',
                                            attributes = ['distinguishedName'])

    class_number = team_string[:3]
    team = team_string[3:]

    if nisObject_search :
        print("  Team nisObject already exists, operation skipped!")
        return 1

    nisObject_dn = "cn={},cn=redacted,ou=redacted,dc=redacted,dc=redacted,dc=redacted".format(team_string)
    
    # Create nisObject
    ldap_connection.add(nisObject_dn,
                        ['top','nisObject'],
                        {'nisMapName' : 'auto.home',
                         'nisMapEntry' : 'redacted:/redacted/redacted/redacted/{class_number}/{team}{semester}'.format(class_number = class_number,
                                                                                                                         team = team,
                                                                                                                         semester = semester)})
