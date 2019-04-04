' excelRefresh.vbs
'     - a tool to use with Windows Task Scheduler to
'     - facilitate automated refreshing of data connections
'     - in Excel Spreadsheets
'
' Example:
'     cscript.exe C:\Users\tim\bin\excelRefresh.vbs C:\Users\tim\doc\bigfile.xlsx
'
'
' says we must declare variables, we will always use it 
Option Explicit

' objArgs is a container that will hold any command line arguments
' so you can pass multiple spreadsheets in on the command line if
' for some reason you want to.
Dim argv
Set argv = WScript.Arguments

' the file system object will just be used to test that any arguments
' passed in on the command line are actually files that exist.
Dim fs
Set fs = CreateObject("Scripting.FileSystemObject")

' wb is the variable we will use to iterate through argv
Dim wb
For Each wb in argv
    If fs.FileExists(wb) Then
        ' Load Excel
        Dim xl
        Set xl = CreateObject("Excel.Application") 
        
        '
        ' Default Excel Options
        xl.Visible = True
        xl.DisplayAlerts = False
        xl.AskToUpdateLinks = False
        xl.AlertBeforeOverwriting = False
        xl.EnableEvents = True 
        '
	' Uncomment the next two lines to use a password, then swap the Open() call (line 48)
	'Dim passwd
	'passwd = 'pass123'

        '
        ' Open the specified workbook, and refresh it, and save it
        Dim owb
	' uncomment this line to use a password, and comment out the next one.
	'Set owb = xl.Workbooks.Open(wb, 3, False, 5, passwd, passwd)
        Set owb = xl.Workbooks.Open(wb, 3, False, 5)
        owb.RefreshAll
        owb.Save
        owb.Close
        '
        ' Quit Excel Nicely
        xl.Quit
        Set owb = Nothing
        Set xl = Nothing
    
    End If
Next

