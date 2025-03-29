Credits
	wimb & alacran : for inspiration and file list with simular project : http://reboot.pro/index.php?showtopic=21977&page=1
	iavn kehayov   : for his superb work on Windows 10 lite (Windows 10 Enterprise 2019 LTSC x64 v2107 lite)



This folder contians the minwin profiles.

A minwin profile has 3 optional subfolder
	Add
		The content of this folder will added to the root of the applied or captured image
	Reg
		*.reg files will added to the applied or captured image
	Remove
		*.txt files with file pattern that should be excluded from apply or capture operation
		*.reg files will added to the applied or captured image

It also should have a WinSxS.ini
	This contians a whitelist for the \Windows\WinSXS folder
		Wildcards should only match one component, outdated version of this component will be removed

The default profile should show a minmal setup-able and useable installation.
	Don't report program xyz.exe does not work
	Alternative profiles or constructive reports are welcome



Filepattern condition examples

	\Windows\ShellExperiences
		matches a folder, so it will be removed, including it sub directorys
		
	!\Windows\ShellExperiences\TileControl.dll
		matches a file, so it will safed (!) from purge
		
	7600-9600 !\Windows\SysWoW64\shsetup.dll
		Only build numbers Windows 7 - 8.1 will process this line
		
	Setup=0 \Windows\System32\SMI
		This line will only be processed if the image is not in setup mode (SystemSetupInprogress=1)
		
	Arch=amd64 !\Windows\SysWow64 ; possible values (amd64|x86|arm64)
		The folder will be saved only if the architecture is AMD64
		
	Lang=de-de !\Windows\system32\kbdgr.dll
		The file will be saved only if the Language is de-de

	FBLANG!es-ES	\Windows\Boot\EFI\es-ES
		Folder will only be removed, if it's not a fallback language

Different conditions can be combined with ',' same conditions with '|'
	7600-9600,Lang=de-de|en-us|fr-fr,Setup=1,Arch=amd64|x86 !\Windows\System32\kernel32.dll
