# MurrpTools - Custom Windows Deployment Toolkit

![MurrpTools_Display](https://github.com/user-attachments/assets/967c5d42-681c-47a1-8290-c8942cfef249)

## About MurrpTools
MurrpTools is an all-in-one Windows toolkit that helps both computer technicians and everyday users:
- Create customized Windows installation/recovery media
- Improve computer performance through smart reinstallation with debloating
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

## Technical Requirements
- **OS**: Windows 10/11 (64-bit) build environment
- **Tools**:
  - DISM [(Windows ADK recommended)](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
  - PowerShell 5.1+
- **Storage**: 15GB free space minimum
- **Windows Install Media**: Windows 10 22H2/11 ISO ([Official](https://www.microsoft.com/en-us/software-download/windows11) or [UUP dump](https://uupdump.net))

## Getting Started Guide

💡 Tip: As always when using Windows installation software. Make sure you back up any computer you plan to use MurrpTools on.
   Reinstalling windows, or using tools to erase the disk will result in data loss.

⚠ **Warning:** This project still being tested. - Use at your own risk. Always backup data before use.


1. **Download the Software**
   **Option 1 - Simple ZIP Download:**
   1. Click the green "Code" button at the top of this page
   2. Select "Download ZIP"
   3. Extract the ZIP file to your preferred location (e.g. Desktop)

   **Option 2 - Git Clone (Advanced):**
   ```powershell
   git clone https://github.com/Dav-Edward/WinKit-MurrpTools.git
   cd MurrpTools
   ```

2. **Install Dependencies and Stage the building location**
   **Choose what works for you:**

   🖱️ **Simple Double-Click Method:**
   1. Go into the MurrpTools folder
   2. Find "1 Dependencies and Staging.cmd" in the folder
   3. You might need to right-click on the file and go into 'Properties'. If there is an 'Unblock' button push it. Otherwise just click OK.
   4. Double-click the file to run it
   5. Click "Yes" if asked for permission

   💻 **PowerShell Method (for advanced users):**
   1. Right-click the Start menu
   2. Select "Windows Terminal (Admin)"
   3. Copy/paste this command:
   ```powershell
   .\MurrpTools\1_Dependencies_and_Staging.ps1 -BuildSelf
   ```
   or to build in a specific folder:
   ```powershell
   .\MurrpTools\1_Dependencies_and_Staging.ps1 -BuildPath C:\Build
   ```
   In which you replace C:\Build with the path you'd like to build the project.

3. **Prepare Drivers**
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
   ```mermaid
   flowchart LR
       A[Download OEM Drivers] --> B[Extract CAB files]
       B --> C[Place in WinPE_Drivers]
   ```

4. **Download Windows Install Media**
   Download either ([Official](https://www.microsoft.com/en-us/software-download/windows11) Windows Install Media (Easy) or create a [UUP dump](https://uupdump.net) ISO file (Advanced) and keep it in a easy to find location like your Downloads folder.

5. **Build MurrpTools Media**
   **Choose your method:**

   🖱️ **Easy Method:**
   1. Find "2 Build MurrpTools Image.cmd" in the folder
   2. You might need to right-click on the file and go into 'Properties'. If there is an 'Unblock' button push it. Otherwise just click OK.
   3. Right-click the file and select "Run as Administrator"
   4. Follow the prompts, you will be asked for the Windows Install Media ISO file, using the file picker that opens select the ISO file you downloaded earlier.

   💻 **PowerShell Method (Admin):**
   ```powershell
   .\MurrpTools\2_Build_MurrpTools_Image.ps1 -IsoPath "C:\path\to\windows.iso"
   ```

6. **Image MurrpTools to Flash Drive**

   You can use any ISO to Flash Drive imaging tool you prefer, but here are instructions using Rufus below:
   
   **Using Rufus**
   
   Rufus Tool is available at: https://rufus.ie
   
   **Reccomended setings for Rufus:**
      - Partition scheme: GPT
      - Target System: UEFI
      - File system: NTFS
      - *(Unchecked)* Create extended label and icon files.
        You may need to click 'Show Advanced format options' to see all options.
        ![image](https://github.com/user-attachments/assets/fe6ac285-3835-43fa-b6d1-489867a8e463)
  
        After you click 'Start' Rufus may prompt with 'Windows User Experience' (eg. Remove Requirements, Disable Bitlocker, etc.)

        Please uncheck all options. Enabling options could cause MurrpTools to fail loading Debloat Tools.`nMurrpTools will already include those features built-in.
        
        ![image](https://github.com/user-attachments/assets/62a82f41-fb74-4ce6-b1f2-ee64dd66b34b)

8. **MurrpTools is ready to be used**
   
   Once your flash drive is imaged using Rufus or your preferred tool, you can now boot off of the flash drive the same way you would a standard Windows Installation media flash drive.

   From there you can use MurrpTools as a toolkit for diagnostics, repair, and recovery, or you can click the "Install Windows with MurrpTools" button on the launcher to install Windows with MurrpTools handling various aspects of the setup including offering options to debloat Windows on it's first start up.

   ![image](https://github.com/user-attachments/assets/b3c336a7-7574-48a3-b34f-27bff006d737)


## Special Thanks
- **Tiny11 Builder Team** - Provided great resources to understand custom image generation.
- **UUP Dump Project** - Both useful project in general, and their scripts helped to understand customizing Windows images, as well as building the ISO file.
- **Hiren's Boot CD PE** - Learned and still learning amazing things done in Hiren's BootCD project. Easily the best multi-purpose boot utility kit out there. [Link](https://www.hirensbootcd.org)

- **Alpha/Beta Testers** - Valuable feedback:
  - Aeros Endeem
  - Sky (Skybox Monster)
  - Lord Flame Stryke
  - Kehvarl
