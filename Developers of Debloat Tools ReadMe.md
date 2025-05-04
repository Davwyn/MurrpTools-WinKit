If you are a debloat tool developer, you can expand MurrpTools to integrate your debloat tool.

Edit DebloatTools.json to add your own tool, the template is as follows:

{
    "Name": "The name of your tool",
    "Enabled": false,
    "Description": "Give a short descrption of your tool",
    "Author": "Your name or handle as the author.",
    "Website": "Website URL the user sees when looking at your tool",
    "FolderName": "A folder name for your tool. Keep it a single word",
    "DownloadURL": "https://Direct URL to your tool",
    "DownloadFilename": "File Name For The Download. Include extension",
    "Executeable": "What file to execute eg script.ps1 or script.cmd",
    "OOBESupported": false
}

# Items described:

**Name:** The name displayed in Debloat Tools

**Enabled:** End user selects if your tool is to be included in MurrpTools build or not

**Description:** Description the end user sees when selecting your tool in Debloat Tools

**Author:** Your name or handle as the author of the tool displayed in Debloat Tools

**Website:** The website address displayed to the end user in Debloat Tools

**FolderName:** Please pick a short single, unqiue name for your tool as the folder to create. Eg. BobsDebloat

**DownloadURL:** The direct link to download your tool. This can be a .PS1 .CMD .BAT or .ZIP file. If you provide a Zip file, MurrpTools will automatically extract the contents of the zip file to your FolderName folder. Make sure your zip file has your files on the root level of the zip and not in a sub-folder.

**DownloadFilename:** Since not all download services correctly tell PowerShell what the filename is of a download, please enter in the filename expected when downloading your file. Eg. BobsDebloat.ps1 or BobsDebloat.zip

**Executable:** What file to execute when your tool is selected. Eg. BobsDebloat.ps1

**OOBESupported:** Set this to true if your tool will work during the Microsoft Out-of-Box Experience running as the SYSTEM user. If it does not, your tool will only be offered if Debloat Tools is run after Windows is fully set up.