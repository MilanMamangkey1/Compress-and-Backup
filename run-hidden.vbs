' ============================================
' Run Compress-and-Backup Hidden
' ============================================
' This script runs compress-and-backup.bat without showing a console window.
' Usage:
'   Double-click run-hidden.vbs              - Runs default job
'   wscript run-hidden.vbs                   - Runs default job
'   wscript run-hidden.vbs "JobName"         - Runs specific job
'   cscript run-hidden.vbs "JobName"         - Same, but with console output
'
' For Task Scheduler:
'   Program: wscript.exe
'   Arguments: "E:\path\to\run-hidden.vbs" "JobName"
' ============================================

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Get the script's directory
scriptPath = WScript.ScriptFullName
scriptDir = fso.GetParentFolderName(scriptPath)

' Build path to batch file
batFile = fso.BuildPath(scriptDir, "compress-and-backup.bat")

' Check if batch file exists
If Not fso.FileExists(batFile) Then
    MsgBox "Error: compress-and-backup.bat not found in:" & vbCrLf & scriptDir, vbCritical, "Run Hidden"
    WScript.Quit 1
End If

' Get optional job name from command-line argument
jobName = ""
If WScript.Arguments.Count > 0 Then
    jobName = WScript.Arguments(0)
End If

' Build command
If jobName = "" Then
    command = """" & batFile & """"
Else
    command = """" & batFile & """ """ & jobName & """"
End If

' Run hidden (0 = hidden window, False = don't wait)
' Use True to wait for completion if needed for Task Scheduler
WshShell.Run command, 0, True

