#! python

import argparse
import sys
import maker


def main() :

    # Argument parsing
    parser = argparse.ArgumentParser(description="Create a NuGet package.", prog="numake")
    parser.add_argument("--template", action="store", dest="app_to_template", metavar="APPLICATION", help="Create a template input file for APPLICATION")
    parser.add_argument("--make", action="store", dest="app_to_package", metavar="APPLICATION", help="Create a nupkg for APPLICATION")
    args = parser.parse_args()

    # Argument handling
    num_args = len(sys.argv) - 1
    if num_args < 2 :
        print("Too few arguments.")
        parser.print_usage()
    elif num_args == 2 :
        if args.app_to_template :
            maker.create_input_template(args.app_to_template)
        elif args.app_to_package :
            maker.create_nupkg(args.app_to_package)
    elif num_args > 2 :
        print("Too many arguments.")
        parser.print_usage()
    
if __name__ == "__main__" :
    main()