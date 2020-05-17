#!/usr/bin/env python3

import os
import re
from MySQLdb import connect, connections, cursors

#####################################
ENROLL_PATH = '/var/lib/enroll/' # trailing slash is necessary
FILE_PATTERN = 'enroll(201[6-9]|20[2-9][0-9])(10|20|30)$' # 2016 - 2099
#####################################

def get_enroll_files(path, pattern):
    files = [path + f for f in os.listdir(path)
             if re.search(pattern, f)]
    return files

def get_mysql_connection():
    connection = connect(host="redacted",
                         user="redacted",
                         passwd="redacted",
                         db="redacted")
    return connection

def get_enrollment_records(mysql_connection, filename):
    semester = filename[-6:]

    query = """
            SELECT
                class_num,
                crn,
                name,
                uin,
                email,
                phone_num,
                cs_username
            FROM
                enrollment
            WHERE
                semester = {};
            """ \
            .format(semester)

    mysql_cursor = mysql_connection.cursor()
    mysql_cursor.execute(query)

    table_description = mysql_cursor.description
    column_names = [col[0] for col in table_description]
    records = [dict(zip(column_names, row)) for row in mysql_cursor]

    return records

def write_dotnew_file(records, filename):
    out_filename = "{}.new".format(filename)
    
    with open(out_filename, 'w') as outfile:
        for row in records:
            line = ("{class_num: <5}:"
                    "{crn: <5}:"
                    "{name: <32}:"
                    "{uin: <9}:"
                    "{email: <16}:"
                    "{phone_num: <24}:"
                    "{cs_username}\n") \
                   .format(**row)
            outfile.write(line)


def main():
    filenames = get_enroll_files(ENROLL_PATH, FILE_PATTERN)
    mysql_connection = get_mysql_connection()
    
    for filename in filenames:
        records = get_enrollment_records(mysql_connection, filename)
        write_dotnew_file(records, filename)

if __name__ == '__main__':
    main()
