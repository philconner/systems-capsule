Python program to generate a NuGet package (.nupkg file).

## Overview
#### What is a nupkg file?
A nupkg file is a NuGet package, used by NuGet, a Windows package manager. However, we don't use NuGet directly, we use Chocolatey, which builds on top of NuGet.
In the context of Chocolatey, a nupkg file is a file used by the Chocolatey application to perform an installation or uninstallation of an application.

Nupkg files follow a strict naming scheme of `<application>.<version>.nupkg`.
They are essentially fancy zip files, with the internal contents being a nuspec file, and a 'tools' directory.
The nuspec file is an XML file named `<application>.nuspec` that contains metadata about the application to be installed (name, version, publisher, etc.).
The 'tools' directory consists of an installation script (ChocolateyInstall.ps1), an uninstallation script (ChocolateyUninstall.ps1), and the necessary installation media (executable installer/uninstaller or MSI).
Sometimes a ChocolateyBeforeModify.ps1 script is used in upgrade scenarios to stop running processes and other tasks necessary to prepare an application to be upgraded, but it is hardly ever needed.

Once the nuspec file and scripts have been filled out, and the needed installation media has been placed in the 'tools' directory, the directory structure can be zipped up into a nupkg using the `choco pack` Chocolatey command.
#### What is Chocolatey?
Chocolatey is a Windows package manager, like `apt` or `yum` but for Windows. Instead of using the public Chocolatey gallery, we host our own internal repo on the redacted server.
#### How do you use a nupkg file?
Chocolatey uses nupkg files whenever `choco install <application> -y` or `choco uninstall <application> -y` is called. It is important to use the `--skip-autouninstaller` flag when using `choco uninstall` to ensure that the uninstallation script is used instead of the auto-uninstall feature.

## Installation
#### Dependencies  
To use this program, you will need a Windows machine with Chocolatey installed. To install Chocolatey, open an elevated powershell prompt, and run the following:  
`Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))`  
#### Install nupkg-maker
1. Clone the repository somewhere convenient.
2. Add the `nupkg-maker` directory to your PATH.
3. Add `.PY` to PATHEXT to be able to call `numake` without the file extension.

## How to use
Running `numake --help` will provide some helpful usage information, but there are 3 main steps to using this program.
1. Run `numake --template <APPLICATION>` to create a template input file in the current directory with the name `<APPLICATION>.json`.
2. Fill out all of the fields in the input file.
3. Run `numake --make <APPLICATION>` to create a nupkg file using the information provided in `<APPLICATION>.json`.

Input file attributes to note:  
- `shortName` - Short name of the application, in all lowercase (i.e. "7zip").
- `longName` - Long name of the application (i.e. "7-Zip"). This can have spaces.
- `fileType` - Type of installer or uninstaller. This will almost always be either "msi" or "exe".
- `fileEmbedded` - Whether or not the installer is embedded in the nupkg (true/false). If the installer is embedded it should be in the 'tools' directory and should be referenced by just its file name. Otherwise, if it is not embedded it should be referenced with a UNC path.
- `silentArgs` - Arguments necessary for the installer or uninstaller to run silently (i.e. "/S /D=C:\\\Progra~1\\\7-Zip"). Make sure to escape backslashes with a second backslash.
- `validExitCodes` - List of exit codes that count as successful. This is usually "0" for executable installers and uninstallers, and is "0, 1641, 3010" for MSIs.
