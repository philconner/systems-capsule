#!/usr/bin/env python3

import os
import re
import csv
from ldap3 import Server, Connection, ALL, NTLM
from MySQLdb import connect, connections, cursors

#####################################
ENROLL_PATH = '/redacted/redacted' # trailing slash is necessary
FILE_PATTERN = 'enroll(201[6-9]|20[2-9][0-9])(10|20|30)$' # 2016 - 2099
#####################################

class EnrollReader(csv.DictReader):
    def __next__(self):
        d = super().__next__()
        return { k:v.strip() for k,v in d.items() }

def get_enroll_files(path, pattern):
    files = [path + f for f in os.listdir(path) 
             if re.search(pattern, f)]
    return files

def read_enroll_file(filename, cs_accounts):
    enroll_records = []
    fieldnames = ['class_num', 'crn', 'name',
                  'uin', 'email', 'phone_num']

    with open(filename) as enrollfile:
        enrollreader = EnrollReader(enrollfile,
                                    delimiter = ':',
                                    fieldnames = fieldnames)
        semester = filename[-6:]

        for row in enrollreader:
            row['semester'] = semester

            if row['uin'] in cs_accounts:
                row['cs_username'] = cs_accounts[row['uin']]
            else:
                row['cs_username'] = ''
            
            if row['phone_num'] == '':
                row['phone_num'] = '0000000000'
            elif len(row['phone_num']) > 20:
                row['phone_num'] = row['phone_num'][:20]
            
            enroll_records.append(row)

    return enroll_records

def get_cs_accounts():
    server_info = Server('redacted', get_info=ALL, use_ssl=True)
    ldap_connection = Connection(server_info,
                                 user='redacted\\redacted',
                                 password='redacted',
                                 authentication=NTLM,
                                 auto_bind=True)

    # Get student accounts and make a dict of uin:username
    cs_accounts = {}
    attributes = ['sAMAccountName', 'employeeNumber']
    users = ldap_connection.search('ou=redacted',
                                   '(objectCategory=person)',
                                   attributes=attributes)
    
    for entry in ldap_connection.entries:
        employeeNumber = str(entry.employeeNumber.value)
        sAMAccountName = str(entry.sAMAccountName.value)
        cs_accounts[employeeNumber] = sAMAccountName

    return cs_accounts

def get_mysql_connection():
    connection = connect(host="redacted",
                         user="redacted",
                         passwd="redacted",
                         db="redacted")
    return connection

def lock_enrollment(mysql_connection):
    mysql_cursor = mysql_connection.cursor()
    mysql_cursor.execute('LOCK TABLE enrollment WRITE;')

def update_enrollment(mysql_connection, enrollment_records):
    mysql_cursor = mysql_connection.cursor()

    for record in enrollment_records:
        upsert_command = """
                         INSERT INTO 
                             enrollment
                                 ( 
                                             semester, 
                                             class_num, 
                                             crn, 
                                             name, 
                                             uin, 
                                             email, 
                                             phone_num, 
                                             cs_username 
                                 ) 
                                 VALUES 
                                 ( 
                                             {semester}, 
                                             "{class_num}", 
                                             {crn}, 
                                             "{name}", 
                                             "{uin}", 
                                             "{email}", 
                                             "{phone_num}", 
                                             "{cs_username}" 
                                 ) 
                         ON DUPLICATE KEY 
                         UPDATE last_update = CURRENT_TIMESTAMP, 
                                cs_username = "{cs_username}",
                                phone_num = "{phone_num}";
                         """ \
                         .format(**record)
        mysql_cursor.execute(upsert_command)
        
    mysql_connection.commit()

def delete_invalid_records(mysql_connection):
    """ 
    If a record is in an enroll file, it will have its timestamp
    updated when update_enrollment() is run.
    
    If a record in the database has not had its timestamp updated,
    then it is no longer in its enroll file and can be deleted.
    """
    
    mysql_cursor = mysql_connection.cursor()
    delete_command = """
                     DELETE FROM
                         enrollment
                     WHERE
                         last_update < ADDDATE(NOW(), INTERVAL - 2 HOUR);
                     """
    mysql_cursor.execute(delete_command)
    mysql_connection.commit()

def main():
    filenames = get_enroll_files(ENROLL_PATH, FILE_PATTERN)
    cs_accounts = get_cs_accounts()

    mysql_connection = get_mysql_connection()
    lock_enrollment(mysql_connection)
    
    for enrollfile in filenames:
        enrollment_records = read_enroll_file(enrollfile, cs_accounts)
        update_enrollment(mysql_connection, enrollment_records)

    delete_invalid_records(mysql_connection)

if __name__ == '__main__':
    main()
