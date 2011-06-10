#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=SETUP04.ICO
#AutoIt3Wrapper_outfile=getprofile.exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;-------------------------------------------------------------------------
; AutoIt script to automate the creation of Wireless Configuration for Eduroam
;
; Written by Gareth Ayres of Swansea University (g.j.ayres@swansea.ac.uk)
;
;
;   Copyright 2009 Swansea University Licensed under the
;	Educational Community License, Version 2.0 (the "License"); you may
;	not use this file except in compliance with the License. You may
;	obtain a copy of the License at
;
;	http://www.osedu.org/licenses/ECL-2.0
;
;	Unless required by applicable law or agreed to in writing,
;	software distributed under the License is distributed on an "AS IS"
;	BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
;	or implied. See the License for the specific language governing
;	permissions and limitations under the License.
;
;
; Updated 29/01/2011
; added extra check on adapter detection in case of strange adapter descriptions or language issues.
;
; Updated 27/01/2011
; Fixed bug with broadcom wireless adapter selection
;
; Updated 10/12/10
; Added wired profile selection
; Fixed bug with debug
;
; Updated 17/06/09 - Gareth Ayres (g.j.ayres@swan.ac.uk)
; Based on Wireless API interface by MattyD (http://www.autoitscript.com/forum/index.php?showtopic=91018&st=0)
;
;
;-------------------------------------------------------------------------


#include "Native_Wifi_Func_V3_3b.au3"
#include <Date.au3>
#include <GUIConstants.au3>
#Include <GuiListView.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#Include <String.au3>

;-------------------------------------------------------------------------
; Global variables and stuff

$CONFIGFILE = "config.ini"
;Check for config File
If (FileExists($CONFIGFILE) ==0) Then
	MsgBox(16,"Error","Config file not found.")
	Exit
EndIf

$VERSION = "V1.2"
$WZCSVCStarted = 0
$progress_meter = 0
;$SSID1 = IniRead($CONFIGFILE, "getprofile", "ssid1", "eduroam")
;$SSID2 = IniRead($CONFIGFILE, "getprofile", "ssid2", "")
;$SSID3 = IniRead($CONFIGFILE, "getprofile", "ssid3", "")
$wireless=IniRead($CONFIGFILE, "su1x", "wireless", "1")
$wired=IniRead($CONFIGFILE, "su1x", "wired", "1")
$DEBUG=IniRead($CONFIGFILE, "su1x", "DEBUG", "0")
$progressbar1 = ""


; ---------------------------------------------------------------
;Functions

Func DoDebug($text)
	If $DEBUG > 0 Then
		BlockInput (0)
		MsgBox (16, "DEBUG", $text)
	EndIf
EndFunc

Func iterateConfig($section)
	; return every value under a given section, useful for iterating
	; multiple ssid to remove/add for instance.
	$content = IniReadSection($CONFIGFILE, $section)
	If @error Then
		MsgBox(4096, "", "Error occured iterating the config file")
	Else
		$size = UBound($content, 1)
		Dim $values[$size - 1]
		For $i = 1 To $size - 1
			$values[$i - 1] = IniRead($CONFIGFILE, $section, $content[$i][0], "")
		Next
		Return $values
	EndIf
EndFunc   ;==>iterateConfig

;Checks if a specified service is running.
;Returns 1 if running.  Otherwise returns 0.
;sc query appears to work in vist and xp
Func IsServiceRunning($ServiceName)
	$pid = Run('sc query ' & $ServiceName, '', @SW_HIDE, 2)
	Global $data
	Do
		$data &= StdOutRead($pid)
	Until @error
	If StringInStr($data, 'running') Then
		Return 1
	Else
		Return 0
	EndIf
EndFunc

;updates the progress bar by x percent
Func UpdateProgress($percent)
		$progress_meter = $progress_meter + $percent
		GUICtrlSetData ($progressbar1,$Progress_meter)
EndFunc

;return OS string for use in XML file
Func GetOSVersion()
    Select
    Case StringInStr(@OSVersion, "VISTA", 0)
        Return "WIN7"
    Case StringInStr(@OSVersion, "7", 0)
        Return "WIN7"
    Case StringInStr(@OSVersion, "XP", 0)
        If @OSServicePack == "Service Pack 2" Then
            Return "XPSP2"
        Else
            Return "XP"
        EndIf
    EndSelect
EndFunc

;simple function to save the profile to a file
Func SaveXMLProfile($name, $profile)
    $filename = $name &"_"&GetOSVersion()&".xml"
    If (FileExists($filename)) Then
        $backup_filename = $filename & ".backup"
        DoDebug("File exists, Backing up and then deleting...")
        If (FileExists($backup_filename)) Then FileDelete($backup_filename)
        FileMove($filename,$backup_filename);
        FileDelete($filename)
    EndIf
    FileWrite($filename, $profile)
EndFunc
;simple function to dump the wired profile to a file
Func DumpWiredXMLProfile($interface)
    $filename = $interface&".xml"
    If (FileExists($filename)) Then
        $backup_filename = $filename & ".backup"
        DoDebug("File exists, Backing up and then deleting...")
        If (FileExists($backup_filename)) Then FileDelete($backup_filename)
        FileMove($filename,$backup_filename)
        FileDelete($filename)
    EndIf
    $cmd = "netsh lan export profile folder=""" & @ScriptDir & """ interface=" & """" & $interface & """"
    DoDebug("[setup]802.3 command="& $cmd)
    RunWait($cmd, "", @SW_HIDE)
EndFunc

Func GetWirelessInterfaces()
	$hClientHandle = _Wlan_OpenHandle()
    if @error Then
        doDebug("No Wireless Service Found. Exiting... Error Code = " & @error)
        SetError(1)
        Return
    EndIf
    $Enum = _Wlan_EnumInterfaces($hClientHandle)
    if @error Then
        doDebug("No Wireless Interfaces Found")
        SetError(1)
        Return
    EndIf
    If (UBound($Enum) == 0) Then
        MsgBox(16, "Error", "No Wireless Adapter Found.")
        SetError(1)
        Return
    Else
		;$pGUID = $Enum[0][0]
		;MsgBox(16, "Error", "Wireless Adapter Found.")
		DoDebug(Ubound($Enum))
		For $i = 0 to UBound( $Enum, 1) - 1
			For $j = 0 to UBound( $Enum, 2) - 1
				DoDebug("$Enum[" & $i & "][" & $j & "]:=" & $Enum[$i][$j])
			Next
		Next
		Return $Enum
    EndIf
EndFunc

Func GetWiredInterfaces()
	$ip = "localhost"
	$objWMIService = ObjGet("winmgmts:{impersonationLevel = impersonate}!\\" & $ip & "\root\cimv2")
	;select all Adapters not manufactured by Microsoft and of type ethernet
	$WiredIfs = $objWMIService.ExecQuery("SELECT * FROM Win32_NetworkAdapter WHERE Manufacturer != 'Microsoft' AND AdapterTypeID = '0'", "WQL", 0x30)
	$networkcount=0
	If IsObj($WiredIfs) Then
		return $WiredIfs
	Else
		DoDebug("No Wired interfaces found")
		SetError(1)
		Return
	EndIf
EndFunc

Func CaptureWirelessProfile($ssid)
	$WirelessIfs = GetWirelessInterfaces()
    if @error Then
        doDebug("No Wireless Interface Found. Exiting... Error Code = " & @error)
        SetError(1)
        Return
    EndIf
    $pGUID = $WirelessIfs[0][0]
    DoDebug("Adapter=" & $WirelessIfs[0][1])

    $hClientHandle = _Wlan_OpenHandle()
    $profile=_Wlan_GetProfileXML($hClientHandle, $pGUID, $ssid)
    if (@error) Then
        doDebug("No "&$ssid&" profile found!")
        doDebug("Adapter= " &  $WirelessIfs[0][1])
        doDebug("wlan_getProfileXML result = " &  $profile)
        MsgBox(1,"Error","No "&$ssid&" profile found on " & $WirelessIfs[0][1])
        SetError(1)
        Return
    EndIf
    return $profile
EndFunc
;-------------------------------------------------------------------------
; Start of GUI code
GUICreate("Config Capture Tool", 350, 100)
GUISetBkColor (0xffff00) ;---------------------------------white
$progressbar1 = GUICtrlCreateProgress (5,5,340,20)

;create empty combo if no wired requested
if(NOT($wired == 0)) Then
	$combo = GUICtrlCreateCombo("Select interface for wired profile", 5, 30, 340, 20 ) ; create first item
Else
	$combo = GUICtrlCreateCombo("", 5, 30, 340, 20 ) ; create first item
EndIf

If(NOT($wireless == 0)) Then
	GetWirelessInterfaces()
	if @error Then
		MsgBox("48","No Wireless!","You have requested for wireless profile capturing however no wireless interface was found")
        $wireless = 0
    EndIf
	;So we did find some wireless interfaces we'll just continue
EndIf

$adapter =""
If(NOT ($wired == "0")) Then
	$WIfs = GetWiredInterfaces()
	if @error Then
		MsgBox("48","No Wired!", "You have requested for wired profile capturing however no wired interface was found")
        $wired = 0
    Else
		;----------------------------------------------------------Drop Down menu of Interfaces
		For $objItem In $WIfs
			$adapter&="Caption: " &$objItem.Caption & @CRLF
			$adapter&="Description: " &$objItem.Description& @CRLF
			$adapter&="Index: " &$objItem.Index & @CRLF
			$adapter&="NetID: " &$objItem.netconnectionid & @CRLF
			$adapter&="Name: " &$objItem.name & @CRLF
			$adapter&="Type: " &$objItem.AdapterType & @CRLF
			$adapter&="MAC Address: "& $objItem.MACAddress & @CRLF
			$adapter&="*********************"
			;DoDebug($adapter)
			;MsgBox(1,"2",$adapter)
			$adapter=""
			GUICtrlSetData(-1,$objItem.description) ; add other item and set a new default
			GUISetState()
			DoDebug("adapter = " & $objItem.netconnectionid & "and desc = " & $objItem.description & "and Type = " & $objItem.AdapterType & " ID: "&$objItem.AdapterTypeID )
		Next		
	EndIf
EndIf
$exitb = GUICtrlCreateButton("Exit", 290, 60, 50)
;-------------------------------------------------------------------------
;TABS
$captureb = GUICtrlCreateButton("Capture", 10, 60, 50)
;-----------------------------------------------------------
GuiSetState(@SW_SHOW)
While 1
    While 1
        $msg = GUIGetMsg()
        ;-----------------------------------------------------------Exit Tool
        If $msg = $exitb Then
            exit
            ExitLoop
        EndIf
        If $msg = $GUI_EVENT_CLOSE Then
            Exit
        EndIf
        ;-----------------------------------------------------------
        ;If capture button clicked
        if $msg = $captureb Then
			;get wireless profiles
			if(NOT($wireless == 0)) Then
				GUICtrlSetData ($progressbar1,0)
				;Capture profile for every key value in the [getprofile] section
                For $CAPSSID in IterateConfig("getprofile")
                    UpdateProgress(10)
                    DoDebug("Capturing "&$CAPSSID)
                    $profile = CaptureWirelessProfile($CAPSSID)
                    if (@error) Then
                        doDebug("Couldn't capture "&$CAPSSID&" profile")
                    Else
                        UpdateProgress(10);
                        SaveXMLProfile($CAPSSID, $profile)
                        UpdateProgress(10);
                    EndIf
                Next
				MsgBox (16, "Wireless exported","The wireless profiles have been exported if all went well. Do not forget to point your config.ini to the right xml files")
			EndIf
			;get wired profiles
			if(NOT($wired == 0)) Then
				;-------------------------------------------------------------------------
				;select value from drop down menu
				$interface = GUICtrlRead($combo)
				doDebug("selected interface = " & $interface)
                ;---------------------------------------------------------------------------------------------------WIRED Capture
                GUICtrlSetData ($progressbar1,0)
                UpdateProgress(20);
                $wired_interface = ""
                ;get description from interface name
                $colItems = GetWiredInterfaces()
                If IsObj($colItems) Then
                    For $objItem In $colItems
                        UpdateProgress(10);
                        if (StringInStr($interface,$objItem.description)) Then 
							$wired_interface=$objItem.netconnectionid
						EndIf
                    Next
                Else
                    DoDebug("[setup]No Adapters found!")
                    MsgBox(1,"Error","No Networking adapters found")
                EndIf
                ;capture profile
                ;backup exisiting 
                UpdateProgress(20);
                if($wired_interface="") Then
					MsgBox(48,"Error","You did not select the interface for wired capturing")
				Else
					DumpWiredXMLProfile($wired_interface)
					UpdateProgress(10);
					MsgBox (16, "Complete","The wired profiles have been exported. Do not forget to point your config.ini to the right xml files")
				EndIf
            EndIf
				
            GUICtrlSetData ($progressbar1,100)
            ;-------------------------------------------------------------------------
            ; All done... report any errors or anything

            ;GUICtrlSetData ($myedit, "Installation Complete!"& @CRLF & "To connect to the SWIS you need to double click the 'uws-vpn' icon on your desktop." )
            ExitLoop
        EndIf
    Wend
Wend
;-------------------------------------------------------------------------
;End of Program when loop ends
;-------------------------------------------------------------------------

exit