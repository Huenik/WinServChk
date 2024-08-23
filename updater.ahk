#SingleInstance, force
if not A_IsAdmin
    Run *RunAs "%A_ScriptFullPath%"
; updater.ahk, run by controller.ahk. Controller.ahk retrieves and creates the json with the latest commit sha.

; Define the GitHub repository API URL to get the latest commit info
repo := "Huenik/WinServChk"
apiUrl := "https://api.github.com/repos/" . repo . "/commits/main"
controllerDl := "https://raw.githubusercontent.com/Huenik/WinServChk/main/controller.ahk"
tempPath := "C:\ProgramFiles\WinServChk\"
jsonFile := tempPath . "latest_commit.json" ; Define the file to save the JSON response
NewController := tempPath . "controller.ahk"
updater := tempPath . "Updater.ahk"
oldController := A_Desktop . "\WinServChk\controller.ahk"
If !FileExist(tempPath) ; Ensure the tempPath directory exists
{
    FileCreateDir, %tempPath%
}

If !FileExist(oldController) ; Ensure the tempPath directory exists
{
    FileDelete,%oldController%
    
}

; Download the latest controller.ahk script
URLDownloadToFile, %controllerDl%, %NewController% ; blocking operation, prevents continuing until DL complete
FileCreateShortcut, %NewController%, %A_Desktop%\WinServChk\WinServChk.lnk, %A_Desktop%\WinServChk\

If FileExist(jsonFile) ;. repo . "/commits/main"
controllerDl := "https://raw.githubusercontent.com/Huenik/WinServChk/main/controller.ahk"
tempPath := "C:\ProgramData\WinServChk\"
jsonFile := tempPath . "latest_commit.json" ; Define the file to save the JSON response
NewController := tempPath . "controller.ahk"
updater := tempPath . "Updater.ahk"
oldController := A_Desktop . "\WinServChk\controller.ahk"
If !FileExist(tempPath) ; Ensure the tempPath directory exists
{
    FileCreateDir, %tempPath%
}

If !FileExist(oldController) ; Ensure the tempPath directory exists
{
    FileDelete,%oldController%
    
}

; Download the latest controller.ahk script
URLDownloadToFile, %controllerDl%, %NewController% ; blocking operation, prevents continuing until DL complete
FileCreateShortcut, %NewController%, %A_Desktop%\WinServChk\WinServChk.lnk, %A_Desktop%\WinServChk\

If FileExist(jsonFile) ; Check if the latest_commit.json file exists and delete it if it does
{
    FileDelete, %jsonFile%
}

FileAppend, %commitSHA%, %jsonFile% ; Save the commit SHA or any other relevant info to the JSON file (example logic, replace with actual usage)

Run, %NewController%, %tempPath% ; Run the downloaded controller script
exitapp
