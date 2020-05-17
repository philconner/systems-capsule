import os
import json
import sys
import subprocess

# Directory where this file is located
source_dir = os.path.dirname(os.path.realpath(__file__))

# Make a template input file
def create_input_template(application) :

    template = open(os.path.normpath("{}/templates/numake_input".format(source_dir)), "r")
    
    template_content = template.read()
    output_content = template_content.format(shortName = application)
    
    output = open("{}.json".format(application), "w")
    output.write(output_content)


# Make output directory structure
def create_output_dirs(package_info) :
    os.makedirs("{}/tools".format(package_info["shortName"]), exist_ok=True)


# Read input file
def get_input(application) :

    try :
        input_file = open("{}.json".format(application), "r")
    except FileNotFoundError as e :
        print("{}.json does not exist within the current directory. Make it first with \'numake --template {}\'.".format(application, application))
        sys.exit(1)

    package_info = json.load(input_file)
    return package_info


# Make nuspec file
def create_nuspec(package_info) :

    template = open(os.path.normpath("{}/templates/nuspec".format(source_dir)), "r")

    template_content = template.read()
    output_content = template_content.format(shortName = package_info["shortName"],
                                             version = package_info["version"],
                                             longName = package_info["longName"],
                                             publisher = package_info["publisher"])

    output = open(os.path.normpath("{}/{}.nuspec".format(package_info["shortName"], package_info["shortName"])), "w")
    output.write(output_content)


# Make ChocolateyInstall script
def create_install_script(package_info) :

    template = open(os.path.normpath("{}/templates/ChocolateyInstall".format(source_dir)), "r")

    template_content = template.read()
    output_content = template_content.format(fileName = package_info["chocoInstallInfo"]["fileName"],
                                             fileEmbedded = package_info["chocoInstallInfo"]["fileEmbedded"],
                                             shortName = package_info["shortName"],
                                             fileType = package_info["chocoInstallInfo"]["fileType"],
                                             silentArgs = package_info["chocoInstallInfo"]["silentArgs"],
                                             validExitCodes = package_info["chocoInstallInfo"]["validExitCodes"])

    output = open(os.path.normpath("{}/tools/ChocolateyInstall.ps1".format(package_info["shortName"])), "w")
    output.write(output_content)

# Make ChocolateyUninstall script
def create_uninstall_script(package_info) :


    template = open(os.path.normpath("{}/templates/ChocolateyUninstall".format(source_dir)), "r")

    template_content = template.read()
    output_content = template_content.format(fileName = package_info["chocoUninstallInfo"]["fileName"],
                                             fileEmbedded = package_info["chocoUninstallInfo"]["fileEmbedded"],
                                             shortName = package_info["shortName"],
                                             fileType = package_info["chocoUninstallInfo"]["fileType"],
                                             silentArgs = package_info["chocoUninstallInfo"]["silentArgs"],
                                             validExitCodes = package_info["chocoUninstallInfo"]["validExitCodes"])

    output = open(os.path.normpath("{}/tools/ChocolateyUninstall.ps1".format(package_info["shortName"])), "w")
    output.write(output_content)


# Run 'choco pack'
def choco_pack(application) :
    try:
        subprocess.check_output(['choco','pack', '{}/{}.nuspec'.format(application, application), '--out', '.'])
    except CalledProcessError as e :
        print("Error while running \'choco pack\':")
        print(e.output)
        sys.exit(1)

# Make a NuGet package
def create_nupkg(application) : 

    package_info = get_input(application)
    create_output_dirs(package_info)
    create_nuspec(package_info)
    create_install_script(package_info)
    create_uninstall_script(package_info)
    choco_pack(application)
