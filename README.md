# MurrpTools - Custom Windows Deployment Toolkit

<!-- ![MurrpTools Preview Image](./assets/murrptools-preview.png) -->

**Warning:** This project is in active development - use at your own risk. Always backup data before use.

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
1. Windows Installation Media Creator
2. Windows Recovery Environment (WinRE)
3. Windows Preinstallation Environment (WinPE)
4. System Repair Toolkit (Startup Repair, Disk Tools)
5. Debloat Tools for Faster Performance
6. Driver Harvesting/Injection Tool
7. Essential Utilities:
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
- **Media**: Windows 10 22H2/11 ISO ([Official](https://www.microsoft.com/en-us/software-download/windows11) or [UUP dump](https://uupdump.net))

💡 Tip: Get Windows ISO files from [Microsoft's official site](https://www.microsoft.com/software-download/windows11)

## Getting Started Guide

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
   .\MurrpTools\1_Dependencies_and_Staging.ps1 -BuildPath .
   ```

3. **Prepare Drivers**
   **For best compatibility:**
   1. Visit your computer manufacturer's support site:
      - [Dell Drivers](https://www.dell.com/support/kbdoc/en-us/000107478/dell-command-deploy-winpe-driver-packs)
      - [HP Drivers](https://ftp.hp.com/pub/caps-softpaq/cmit/softpaq/WinPE10.html)
      - [Lenovo Drivers](https://support.lenovo.com/ca/en/solutions/ht074984)
      - [Acer Drivers](https://community.acer.com/en/kb/articles/15378)
   
   2. Download the Windows PE drivers package(s)
   
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

4. **Build MurrpTools Media**
   **Choose your method:**

   🖱️ **Easy Method:**
   1. Find "2 Build MurrpTools Image.cmd" in the folder
   2. You might need to right-click on the file and go into 'Properties'. If there is an 'Unblock' button push it. Otherwise just click OK.
   3. Right-click the file and select "Run as Administrator"

   💻 **PowerShell Method (Admin):**
   ```powershell
   .\MurrpTools\2_Build_MurrpTools_Image.ps1 -IsoPath "C:\path\to\windows.iso"
   ```

## Special Thanks
- **Tiny11 Builder Team** - Custom image inspiration
- **UUP Dump Project** - ISO creation techniques
- **Beta Testers** - Valuable feedback:
  - Aeros Endeem
  - Sky (Skybox Monster)
