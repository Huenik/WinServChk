#SingleInstance Force
SetWorkingDir %A_ScriptDir%
if not A_IsAdmin
    Run *RunAs "%A_ScriptFullPath%"

;==========================================================================================================================================================
; Read the local version file, if it exists
localVersionFile := "C:\ProgramData\WinServChk\gitVersion.json"
if FileExist(localVersionFile)
{
    FileRead, localVersion, %localVersionFile%
    if ErrorLevel != 0
        localVersion := ""
}
else
{
    localVersion := ""
}

; Define the GitHub repository API URL to get the latest commit info
repo := "Huenik/WinServChk"
apiUrl := "https://api.github.com/repos/" . repo . "/commits/main"
tempPath := "C:\ProgramData\WinServChk\"
jsonFile := tempPath . "latest_commit.json" ; Define the file to save the JSON response
updater := tempPath . "Updater.ahk"
updaterDl := "https://raw.githubusercontent.com/Huenik/WinServChk/main/updater.ahk"

; Get committed version
URLDownloadToFile, %apiUrl%, %jsonFile% ; Download the latest commit info as a JSON file
if ErrorLevel
{
    MsgBox, 16, Error, Failed to download commit info.
    ExitApp
}

FileRead, jsonData, %jsonFile% ; Read the JSON file and extract the commit SHA
if ErrorLevel
{
    MsgBox, 16, Error, Failed to read commit info.
    ExitApp
}

; Extract the commit SHA using regex
regex := """sha"":\s*""([a-f0-9]{40})"""
if RegExMatch(jsonData, regex, match)
{
    commitSHA := match1
    ; MsgBox, The current commit SHA is: %commitSHA%`r`rREMOVE AFTER DEV ; Un-comment this line for debugging
}
else
{
    MsgBox, 16, Error, SHA not identified.
    ExitApp
}

FileDelete, %jsonFile% ; Clean up by deleting the JSON file

; Compare versions and run updater if needed
URLDownloadToFile, %updaterDl%, %updater%
Run %updater%
ExitApp

;==========================================================================================================================================================
updateDoneOrSkipped:
; Ensure the necessary files exist before proceeding
defaultServicesFile := A_ScriptDir . "\ListOfDefaultWindowsServices.txt"
allowedServicesFile := A_ScriptDir . "\ListOfAllowedServices.txt"
If (!FileExist(defaultServicesFile) || !FileExist(allowedServicesFile)) {
    MsgBox, 16, Error, Required files are missing.`nPlease make sure `ListOfDefaultWindowsServices.txt` and `ListOfAllowedServices.txt` are present in the script's directory.
    ExitApp
}

; Set output file path dynamically to the current user's Desktop
outputDir := A_Desktop . "\WindowsServiceChecker"
If (!FileExist(outputDir)) {
    FileCreateDir, %outputDir%
}
outputFile := outputDir . "\RunningServices.txt"

GUI = 0

MsgBox, Just to be clear this isnt the finished program.

start:
psCommand := "Get-Service | Select-Object -Property DisplayName, Status" ; Define the PowerShell command
FileDelete, %outputFile% ; Delete the output file if it exists and pause briefly
Sleep, 500
RunWait, powershell -Command "%psCommand% | Out-File -FilePath '%outputFile%' -Encoding utf8",, Hide ; Run the PowerShell command and redirect the output to the file
FileRead, fileContent, %outputFile% ; Read the content of the output file
fileContent := RegExReplace(fileContent, "(_[0-9a-fA-F]{3,8})", "") ; Remove LUIDs from services (hex format)
fileContent := RegExReplace(fileContent, "DisplayName\s+Status\r?\n-+\s+-+\r?\n") ; Remove the header lines
fileContent := RegExReplace(fileContent, "([^\r\n]+?)\s{2,}(Running|Stopped)", "$1`r") ; Remove "Running" and "Stopped"
fileContent := RegExReplace(fileContent, "\s*\r", "`r") ; Remove all double whitespaces and empty lines
FileDelete, %outputFile% ; Save the modified content back to the output file
FileAppend, %fileContent%, %outputFile%
Sleep, 2000
FileRead, DefaultServices, %defaultServicesFile% ; Read ListOfDefaultWindowsServices.txt
FileRead, AllowedServices, %allowedServicesFile% ; Read ListOfAllowedServices.txt
DefaultServices := DefaultServices . "`r" . AllowedServices ; Concatenate Default and Allowed Services
FileRead, RunningServices, %outputFile% ; Read RunningServices.txt
DefaultServices := RegExReplace(DefaultServices,"\r\r","\r")
RunningArray := StrSplit(RunningServices, "`n") ; Split the services into arrays
DefaultArray := StrSplit(DefaultServices, "`n")
totalServices := RunningArray.Length() ; Initialize variables
nonDefaultCount := 0
DefaultArrayLength := DefaultArray.Length()
nonDefaultServices := [] ; Array to store non-default services
servicesToRemove := []

If(GUI = 0) { ; Create GUI
	Gui, Add, Text, x10 y20 w300 h20 vNonDefaultCountLabel, Number of non-default services running: 0
	Gui, Add, ListView, x10 y50 w600 h300 vServiceListView gServiceSelected Grid, Non-Default Services|Status|Description
	
	Gui, Add, Edit, x10 y370 w600 h30 vSelectedServiceReadOnly ReadOnly
	Gui, Add, Edit, x10 y410 w600 h60 vSelectedServiceSCQCReadOnly ReadOnly
	
	Gui, Add, Button, x10 y480 w100 h30 gStopService vStopServiceButton, Stop Service
	Gui, Add, Button, x120 y480 w100 h30 gSkipService vSkipServiceButton, Whitelist Service
	Gui, Add, Button, x230 y480 w100 h30 gListForRemoval vListForRemovalButton, List For Removal
	Gui, Add, Button, x340 y480 w100 h30 gShowRemovalList vShowRemovalListButton, Show Removal List
	Gui, Add, Button, x450 y480 w100 h30 gChangeDescription vChangeDescription, Change Desc
	Gui, Add, Button, x540 y12 w70 h30 gRefresh vRefreshButton, Refresh List
	
}
GUI = 0
for each, runningService in RunningArray ; Loop through RunningServices and check if each service is in DefaultServices
{
	runningService := Trim(runningService) ; Trim any extraneous whitespace
	if (runningService = "") ; Skip empty lines
		continue
	runningService := RegExReplace(runningService,"(_[0-9a-fA-F]{3,8})","") ; Modified to match hex LUIDs too
	RunWait, cmd.exe /c sc queryex "%runningService%",, Hide ; Check if the service exists
	If (ErrorLevel = 0) ; Service exists
	{
		isDefault := false ; Check if the service is not in the DefaultArray
		for each, defaultService in DefaultArray
		{
			if (runningService = Trim(defaultService))
			{
				isDefault := true
				break
			}
		}
		if (!isDefault) ; If not in DefaultArray, it's a non-default service
		{
			nonDefaultCount++
			nonDefaultServices.Push(runningService)
			RunWait, %comspec% /c sc GetKeyName "%runningService%" > temp.txt,, Hide ; Get service key name
			FileRead, keyName, temp.txt
			keyName := SubStr(Trim(keyName), 39)
			
			RunWait, %comspec% /c sc query "%runningService%" | findstr "STATE" > temp.txt,, Hide ; Get service status
			FileRead, status, temp.txt
			if (InStr(status, "STOPPED"))
				Status := "STOP"
			else if (InStr(status, "RUNNING"))
				Status := "RUN"
			else
				Status := "UKN"
			RunWait, %comspec% /c sc EnumDepend "%runningService%" > temp.txt,, Hide ; Get service dependencies
			FileRead, dependencies, temp.txt
			RunWait, %comspec% /c sc Qdescription "%runningService%" | Findstr "DESCRIPTION"> temp.txt,, Hide ; Get service description
			FileRead, description, temp.txt
			description := RegExReplace(description, "DESCRIPTION:\s*", "")
			FileDelete, temp.txt ; Clear temp.txt after reading
			LV_Add("", runningService, status, description)
			GuiControl,, NonDefaultCountLabel, Services Installed: %totalServices% | Non-Default: %nonDefaultCount% ; Update the number of non-default services running
			LV_ModifyCol(2, "Sort") ; Sort by Status column
			Gui, Show, , Windows Service Checker ; Show GUI
		}
	}
}
LV_ModifyCol(2, "Sort") ; Sort by Status column
Gui, Show, , Huenik's Windows Service Checker (DEV); Show GUI
if (servicesToRemove.Length() = 0) { ; Check if servicesToRemove array is empty
	GuiControl, Hide, vShowRemovalListButton ; Hide the Show Removal List button if the array is empty
} else {
	GuiControl, Show, vShowRemovalListButton ; Show the Show Removal List button if the array is not empty
}
return

ServiceSelected:
LV_GetText(SelectedService, LV_GetNext("", "Focused"), 1) ; Get the selected row number
If (SelectedService != "")
{
	GuiControl,, SelectedServiceReadOnly, %SelectedService% ; Update the control with the selected service
	RunWait, %comspec% /c sc qc "%SelectedService%" > temp.txt,, Hide ; Get service configuration
	FileRead, SelectedServiceSCQC, temp.txt
	GuiControl,, SelectedServiceSCQCReadOnly, %SelectedServiceSCQC% ; Update the control with the selected service configuration
	FileDelete, temp.txt ; Clear temp.txt after reading
}

; move buttons depending on how many lines are in SelectedServiceSCQC
LineCount := StrSplit(SelectedServiceSCQC, "`n")
LineCount := LineCount.length()
If (LineCount > 2) 
{
	MsgBox, % LineCount
	moveButtonsYBy := (LineCount * 16) + LineCount ; 16 seems to be perfect size for text in this gui, upped to 17 per line.
	
	GuiControl, Move, StopServiceButton, "x" 10 "y" 480+moveButtonsYBy "w" 100 "h" 30
	GuiControl, Move, SkipServiceButton, "x" 120 "y" 480+moveButtonsYBy "w" 100 "h" 30
	GuiControl, Move, ListForRemovalButton, "x" 230 "y" 480+moveButtonsYBy "w" 100 "h" 30
	GuiControl, Move, ShowRemovalListButton, "x" 340 "y" 480+moveButtonsYBy "w" 100 "h" 30
	GuiControl, Move, ChangeDescription, "x" 450 "y" 480+moveButtonsYBy "w" 100 "h" 30
	Gui, Show, , Windows Service Checker ; Show GUI
}
return

Refresh:
GuiControl,, NonDefaultCountLabel, Services Installed: %totalServices% | Non-Default: %nonDefaultCount%
LV_Delete()
GUI = 1
Gui, Show, , Windows Service Checker
goto, start
return

StopService:
LV_GetText(SelectedService, LV_GetNext("", "Focused"), 1) ; Get the selected row number and service name
if (SelectedService = "")
{
        MsgBox, No service selected.
        return
}

	    ; Stop the selected service
RunWait, %comspec% /c sc stop "%SelectedService%", , Hide
RunWait, %comspec% /c sc config "%SelectedService%" start= demand, , Hide

	    ; Refresh the specific service status
RunWait, %comspec% /c sc query "%SelectedService%" | findstr "STATE" > temp.txt,, Hide
FileRead, status, temp.txt
FileDelete, temp.txt
	if (InStr(status, "STOPPED")) ; Determine the new status
		Status := "STOP"
	else if (InStr(status, "RUNNING"))
		Status := "RUN"
	else
		Status := "UKN"
LV_Modify(LV_GetNext("", "Focused"), "Col2", Status) ; Update the status of the selected service in the ListView
nonDefaultCount-- ; Update the number of non-default services running
GuiControl,, NonDefaultCountLabel, Number of non-default services running: %nonDefaultCount%
return

SkipService:
LV_GetText(SelectedService, LV_GetNext("", "Focused"), 1) ; Get the selected row number
If (SelectedService != "")
{
		MsgBox, 4, Whitelist Service, Do you want to whitelist this service?
		IfMsgBox, Yes
		{
			FileAppend, %SelectedService%`r, ListOfAllowedServices.txt
			FileRead, AllowedServices, ListOfAllowedServices.txt
			AllowedServices := RegExReplace(AllowedServices,"\r\r","\r")
			FileDelete, ListOfAllowedServices.txt
			FileAppend, %AllowedServices%, ListOfAllowedServices.txt
			LV_Delete(LV_GetNext("", "Focused"))
		}
		SelectedService := ""
		GuiControl,, SelectedServiceReadOnly, %SelectedService%
		nonDefaultCount-- ; Update the number of non-default services running
		GuiControl,, NonDefaultCountLabel, Number of non-default services running: %nonDefaultCount%
	}
	return
ChangeDescription:
    LV_GetText(SelectedService, LV_GetNext("", "Focused"), 1) ; Get the selected row number and the service name
    if (SelectedService = "")
    {
        MsgBox, No service selected.
        return
    }
    
    ; Refresh the specific service status
    RunWait, %comspec% /c sc qdescription "%SelectedService%" | findstr "DESCRIPTION" > temp.txt,, Hide
    FileRead, Description1, temp.txt
    Description1 := RegExReplace(Description1, "DESCRIPTION:\s*", "")
    FileDelete, temp.txt

    ; Prompt the user for a new description
    InputBox, Description2, Enter New Description, Please enter a New Description.
    if (ErrorLevel) ; User pressed Cancel
    {
        MsgBox, You cancelled the operation.
        return
	}
	Description3 := Description2 . " | " . Description1 ; Combine the new description with the old one and update the service description
	RunWait, %comspec% /c sc description "%SelectedService%" "%Description3%" > temp.txt,, Hide
	FileRead, Description4, temp.txt
	MsgBox, Description Change Returned:`r%Description4%, New Description
	FileDelete, temp.txt

		    ; Update the status of the selected service in the ListView
	LV_Modify(LV_GetNext("", "Focused"), "Col3", Description3)

	return
	
ListForRemoval:
	LV_GetText(SelectedService, LV_GetNext("", "Focused"), 1) ; Get the selected row number
	If (SelectedService != "")
	{
	if (servicesToRemove.HasKey(SelectedService)) ; Check if the service is already in the removal list
	{
		MsgBox, Service %SelectedService% is already in the removal list.
		SelectedService := ""
		GuiControl,, SelectedServiceReadOnly, %SelectedService%
	}
	else
	{
		servicesToRemove.Push(SelectedService) ; Add the service to the removal list
		MsgBox, Service %SelectedService% added to removal list.
		
		GuiControl, Show, vShowRemovalListButton ; Show the Show Removal List button
		
		LV_Delete(LV_GetNext("", "Focused")) ; Remove the service from the ListView
		
		nonDefaultCount-- ; Update the number of non-default services running
		GuiControl,, NonDefaultCountLabel, Number of non-default services running: %nonDefaultCount%
		SelectedService := ""
		GuiControl,, SelectedServiceReadOnly, %SelectedService%
	}
}
	return
	
ShowRemovalList:
	removalList := ""
	for index, service in servicesToRemove
	{
		removalList .= service "`n"
	}
	MsgBox, 4, Removal List, %removalList%`n`nRemove from Registry?
	IfMsgBox, Yes
	{
	GuiControl, Hide, RefreshButton
	Gui, Add, Button, x300 y12 w150 h30 gRemoveFromRegistry, Remove from Registry
	Gui, Add, Button, x450 y12 w100 h30 gNevermind, Nevermind
	Gui, Show
}
	return
	
Nevermind: 
	for index, service in servicesToRemove ; Add services back to the list
	{
		LV_Add("", service)
	}
	servicesToRemove := [] ; Clear the removal list and remove the buttons from the GUI
	GuiControl,, SelectedServiceReadOnly, % ""
	GuiControl,, SelectedServiceReadOnly, %SelectedService%
	GuiControl,, SelectedServiceReadOnly, %SelectedService%
	GuiControl, Hide, Button6
	GuiControl, Hide, Button7
	return
	
RemoveFromRegistry: ; Create a file with the list of services being removed, named and dated
	FormatTime, dateTime,, yyyy-MM-dd_HH-mm-ss
	removalFileName := "ServiceRemovalList_" dateTime ".txt"
	FileAppend, %removalList%, %removalFileName%
	MsgBox, 4, Remove from Registry, Are you sure you want to remove these services from the registry? ; Prompt user if they are sure
	IfMsgBox, Yes
	{
		for index, service in servicesToRemove ; Loop through services to delete each one
		{
			RunWait, cmd.exe /k sc delete "%service%" ; Open CMD and use sc.exe delete to remove service
			sleep 250
		}
		
		servicesToRemove := [] ; Clear the removal list and remove the buttons from the GUI
		GuiControl,, SelectedServiceReadOnly, % ""
		GuiControl,, SelectedServiceReadOnly, %SelectedService%
		GuiControl,, SelectedServiceReadOnly, %SelectedService%
		GuiControl, Hide, Button6
		GuiControl, Hide, Button7
	}
	return
	
;-----------------------------------------------------------------------------------------------------------------------------------------
GuiClose:
	ExitApp
	return
	
f3::ExitApp
f5::goto, Refresh