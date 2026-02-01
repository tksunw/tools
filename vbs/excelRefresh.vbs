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

' Create Excel once outside the loop for efficiency
Dim xl
Set xl = CreateObject("Excel.Application")

' Default Excel Options (optimized for automated processing)
xl.Visible = False
xl.DisplayAlerts = False
xl.AskToUpdateLinks = False
xl.AlertBeforeOverwriting = False
xl.EnableEvents = True

' Uncomment the next line to use a password
'Dim passwd
'passwd = "pass123"

' wb is the variable we will use to iterate through argv
Dim wb
Dim owb

For Each wb in argv
    If fs.FileExists(wb) Then
        On Error Resume Next

        ' Open the specified workbook, refresh it, and save it
        ' uncomment this line to use a password, and comment out the next one.
        'Set owb = xl.Workbooks.Open(wb, 3, False, 5, passwd, passwd)
        Set owb = xl.Workbooks.Open(wb, 3, False, 5)

        If Err.Number = 0 Then
            owb.RefreshAll
            ' Wait for all asynchronous queries to complete before saving
            xl.CalculateUntilAsyncQueriesDone
            owb.Save
            owb.Close
            WScript.Echo "Successfully refreshed: " & wb
        Else
            WScript.Echo "Error opening " & wb & ": " & Err.Description
        End If

        Set owb = Nothing
        Err.Clear
        On Error Goto 0
    Else
        WScript.Echo "File not found: " & wb
    End If
Next

' Quit Excel once after processing all workbooks
xl.Quit
Set xl = Nothing
Set fs = Nothing
