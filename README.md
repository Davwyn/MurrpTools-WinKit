# MurrpTools - Custom Windows Deployment Toolkit

<div align="center"><img width="600" height="600" alt="MurrpTools Logo with text glow 600px" src="https://github.com/user-attachments/assets/c2fa8b6f-f019-4a92-91be-134dcb0dbf55" /></div>
<img width="1024" height="768" alt="MurrpTools Screen" src="https://github.com/user-attachments/assets/21b3079c-346d-4985-9c5d-768ee67b9fd2" />

<br></br>
<a href="https://github.com/Davwyn/MurrpTools-WinKit/releases/latest"><img alt="GitHub Release" src="https://img.shields.io/github/v/release/Davwyn/MurrpTools-WinKit?display_name=release&style=for-the-badge"></a>


## License
<a href="https://github.com/Davwyn/MurrpTools-WinKit/blob/main/LICENSE"><img alt="GitHub License" src="https://img.shields.io/github/license/Davwyn/MurrpTools-WinKit?style=for-the-badge"></a>

MurrpTools is licensed under ![GNU GPL v3 License](https://github.com/Davwyn/MurrpTools-WinKit/blob/main/LICENSE) excluding the Dependencies directory whose licenses are each to their own. See ![Dependencies README](https://github.com/Davwyn/MurrpTools-WinKit/blob/main/Dependencies/README.md) for more details.

## About MurrpTools
MurrpTools is an all-in-one Windows toolkit that helps both computer technicians and everyday users:
- Install Windows without the bloat and have full control of your Windows experience
- Create customized Windows installation/recovery media
- Improve computer performance
- Simplify system repairs and recovery for Windows computers

**Key Features:**
- Combined Windows Installation/Recovery Environment
- Debloat and Privacy Tools
- Driver Backup & Injection Capabilities
- Multiple Third-Party Utilities

**Complete Toolset Includes:**
- Windows Installation Media Creator
- Windows Recovery Environment (WinRE)
- Windows Preinstallation Environment (WinPE)
- System Repair Toolkit (Startup Repair, Disk Tools)
- Debloat Tools for Faster Performance
- Driver Harvesting/Injection Tool
- Essential Utilities:
   - 7-Zip File Manager
   - Defraggler Disk Optimizer
   - AOMEI Partition Editor
   - CPUID Hardware Identification
   - Treesize Disk Usage Explorer
   - Explorer++ File Manager
   - Wipefile Secure File Eraser
 
<img width="1024" height="384" alt="Side by side StartMenu" src="https://github.com/user-attachments/assets/3bcd2ce9-631b-46b6-8ea5-5992d3b28e46" />

## Technical Requirements
- **OS**: Windows 10/11 (64-bit) build environment
- **Tools**:
  - DISM *Built into Windows
  - Windows PowerShell 5.1+
- **Storage**: 15GB free space minimum
- **Windows Install Media**: Windows 10 22H2/11 ISO ([Official](https://www.microsoft.com/en-us/software-download/windows11) or [UUP dump](https://uupdump.net))

## Video Tutorial
<a href="https://www.youtube.com/watch?v=LYYtJzbrzHE"><img width=50% height=auto alt="MurrpTools Video Screenshot" src="https://github.com/user-attachments/assets/b218f6ab-f6ef-4791-a40e-572af022839f" /><br /><b>Video Tutorial</b></a>

## Getting Started Guide

💡 Tip: As always when using Windows installation software. Make sure you back up any computer you plan to use MurrpTools on.
   Reinstalling windows, or using tools to erase the disk will result in data loss.

⚠ **Warning:** This project still being tested. - Use at your own risk. Always backup data before use.


1. **--Download the Software--**
   
   **-Option 1 - Simple ZIP Download-**
   1. Download the latest release zip:
      
      <a href="https://github.com/Davwyn/MurrpTools-WinKit/releases/latest"><img alt="GitHub Release" src="https://img.shields.io/github/v/release/Davwyn/MurrpTools-WinKit?display_name=release&style=for-the-badge"></a>
   2. Extract the ZIP file to your preferred location (e.g. Desktop)

   **-Option 2 - Git Clone (For advanced Users)-**
   ```powershell
   git clone https://github.com/Dav-Edward/WinKit-MurrpTools.git
   cd MurrpTools
   ```

2. **--Install Dependencies and Stage the building location--**
   
   **Choose what works for you:**

   🖱️ **-Simple Double-Click Method-**
   1. Go into the MurrpTools folder
   2. Find "1 Dependencies and Staging.cmd" in the folder
   3. You might need to right-click on the file and go into 'Properties'. If there is an 'Unblock' button push it. Otherwise just click OK.
   4. Double-click the file to run it
   5. Click "Yes" if asked for permission

   💻 **-PowerShell Method (for advanced users)-**
   1. Right-click the Start menu
   2. Select "Windows Terminal (Admin)"
   3. Copy/paste this command:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   & ".\MurrpTools\1 Dependencies and Staging.ps1" -BuildSelf
   ```
   or to build in a specific folder:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   & ".\MurrpTools\1 Dependencies and Staging.ps1" -BuildPath C:\Build
   ```
   In which you replace C:\Build with the path you'd like to build the project.

3. **--Prepare Drivers--**
   
   **For best compatibility:**
   1. Visit your computer manufacturer's support site:
      - [Dell Drivers](https://www.dell.com/support/kbdoc/en-us/000107478/dell-command-deploy-winpe-driver-packs)
      - [HP Drivers](https://ftp.hp.com/pub/caps-softpaq/cmit/softpaq/WinPE10.html)
      - [Lenovo Drivers](https://support.lenovo.com/ca/en/solutions/ht074984)
      - [Acer Drivers](https://community.acer.com/en/kb/articles/15378)
   
   2. Download the Windows PE drivers package(s) sometimes called SCCM packages
   
   3. Extract all files (right-click CAB files > "Extract All")
   
   4. Copy extracted folders to:
      ```
      MurrpTools/WinPE_Drivers/
      ```

4. **--Download Windows Install Media--**
   
   Download either ([Official](https://www.microsoft.com/en-us/software-download/windows11) Windows Install Media (Easy) or create a [UUP dump](https://uupdump.net) ISO file (Advanced) and keep it in a easy to find location like your Downloads folder.

5. **--Select Desired Debloat Tools (Optional)--**

   Inside of the MurrpTools folder is a file called DebloatTools.json which contains a list of available debloat tools you can build into MurrpTools.
   To make changes on desired debloat tools:
   1. Open the DebloatTools.json file in Notepad or some other basic text editor of your choice.
   2. After the name of each tool there is an "Enabled" line that reads 'true' or 'false'. Set to true if you want to enable the tool, or false if you want to disable it.

   ⚠ Note: Do not edit the other values of the JSON files unless you are a developer testing adding new tools. Editing the other values in the JSON file can cause the debloat tools features to break, or MurrpTools fail to build.


6. **--Build MurrpTools Media--**
    
   **Choose your method:**

   🖱️ **-Easy Method-**
   Go to the folder you selected to unpack to back in step #2. If you choose to build at current location the script will be in the same folder.
   1. Find "2 Build MurrpTools Image.cmd" in the folder
   2. You might need to right-click on the file and go into 'Properties'. If there is an 'Unblock' button push it. Otherwise just click OK.
   3. Right-click the file and select "Run as Administrator"
   4. Follow the prompts, you will be asked for the Windows Install Media ISO file, using the file picker that opens select the ISO file you downloaded earlier.

   💻 **-PowerShell Method (For advanced users)-**
   Go to the folder you selected to unpack to back in step #2. If you choose to build at current location the script will be in the same folder.
   1. Right-click the Start menu
   2. Select "Windows Terminal (Admin)"
   3. Copy/paste this command:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   & ".\MurrpTools\2 Build MurrpTools Image.ps1" -IsoImage "C:\path\to\windows.iso"
   ```

7. **--Image MurrpTools to Flash Drive--**

   You will need an ISO to Flash Drive imaging tool to 'flash' the MurrpTools software to a flash drive and make it bootable.

   You can use any ISO to Flash Drive imaging tool you prefer, but here are instructions using Rufus below:
   
   **-Using Rufus-**
   
   Rufus Tool is available at: https://rufus.ie

   Download either the full or portable version of Rufus and open it and select the below settings
   
   **Reccomended setings for Rufus:**
      - Partition scheme: GPT
      - Target System: UEFI
      - File system: NTFS
      - *(Unchecked)* Create extended label and icon files.
        You may need to click 'Show Advanced format options' to see all options.
        
        ![image](https://github.com/user-attachments/assets/fe6ac285-3835-43fa-b6d1-489867a8e463)
  
        After you click 'Start' Rufus may prompt with 'Windows User Experience' (eg. Remove Requirements, Disable Bitlocker, etc.)

        Please uncheck all options. Enabling options could cause MurrpTools to fail loading Debloat Tools. MurrpTools will already include those features built-in.
        
        ![image](https://github.com/user-attachments/assets/62a82f41-fb74-4ce6-b1f2-ee64dd66b34b)

9. **--MurrpTools is ready to be used--**
   
      Once your flash drive is imaged using Rufus or your preferred tool, you can now boot off of the flash drive the same way you would a standard Windows Installation media flash drive.

      From there you can use MurrpTools as a toolkit for diagnostics, repair, and recovery, or you can click the "Install Windows with MurrpTools" button on the launcher to install Windows with MurrpTools handling various aspects of the setup including offering options to debloat Windows on it's first start up.

<img width="571" height="471" alt="Installing Windows Tip" src="https://github.com/user-attachments/assets/11068142-5750-41be-aded-1799abc13030" />



## Special Thanks
- **Tiny11 Builder Team** - Provided great resources to understand custom image generation.
- **UUP Dump Project** - Both useful project in general, and their scripts helped to understand customizing Windows images, as well as building the ISO file.
- **Hiren's Boot CD PE** - Learned and still learning amazing things done in Hiren's BootCD project. Easily the best multi-purpose boot utility kit out there. [Link](https://www.hirensbootcd.org)

- **Alpha/Beta Testers** - Valuable feedback:
  - Aeros Endeem
  - Sky (Skybox Monster)
  - Lord Flame Stryke
  - Kehvarl
  - Talonius

## Message to Debloat Tool Developers
If you are interested in adding your Debloat Tool to MurrpTools, please read the "Developers of Debloat Tools ReadMe.md" file in this repo.

You can either send a Pull Request to edit DebloatTools.json, or open an Issue supplying all of the details of your debloat tool to be included.

## Help This Project
The base MurrpTools project has been developed souly by myself, Davwyn.

I would greatly appreciate help from other developers in the following categories:

- Bug hunting/fixing: If you can find something wrong, please share or make a pull request

- Code improvements: If you can offer code improvements please create an Issue or Pull Request and I'll review it when I can

- Davwyn's Debloat Improvements: [Davwyn's Debloat Script](https://github.com/Davwyn/DavwynsDebloater) is very rough around the edges. If developers are willing to lend a hand, I would love it if we can colaborate to make a simple UI for the tool so users can easily make their debloat selections and refactor the code entirely.

- Tutorials: Do you make slick tutorials? Please let me know if you post a tutorial for MurrpTools and I'll add your tutorial to a Tutorials page!

- Spread the Word: I made this tool entirely for friends that need to use Windows. Word of mouth is powerful. If you like MurrpTools, tell your friends!

- Want to donate? I would always appreciate even a [small tip via Stream Elements](https://streamelements.com/davwyn/tip).
