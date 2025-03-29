Dim shl
Set shl = CreateObject("WScript.Shell")
Set Shell = CreateObject("WScript.Shell")
Dim strMsg,inp01,strTitle,strFlag
Dim WshShell, i
Set Shell = CreateObject("WScript.Shell")
Answer = MsgBox("" & vbNewLine & "Do you want to restart now?",vbYesNo,"Restart?")
	If Answer = vbYes Then
	Call shl.Run("wpeutil reboot",0,true)
		Ending = 1
	If Answer = vbNo Then
		WScript.Quit 0
		Ending = 1
	End If
End If