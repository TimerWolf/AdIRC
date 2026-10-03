;######################################
; AdIRC: SiteInvite-Interface         #
; Revision: 7                         #
; Date created: 05/09/2026            #
; Date last modified: 03/10/2026      #
; Author: Whiskey                     #
; #####################################

alias siteinvite {
  dialog -m siteinviteDialog siteinviteDialog
}

; ------------------------------------------------------------------------------
; Safe ini write helper
; ------------------------------------------------------------------------------

alias safeWriteIni {
  if ($4 != $null) {
    writeini $qt($1) $2 $3 $qt($4-)
  } else {
    remini $qt($1) $2 $3
  }
}

; ------------------------------------------------------------------------------
; Strip leading '#' in a CSV list
; ------------------------------------------------------------------------------

alias stripHashCSV {

  if ($1 == $null) {
    return
  }

  var %outputTokenList
  var %tokenCount = $numtok($1-,44)
  var %currentIndex = 1

  while (%currentIndex <= %tokenCount) {

    var %token = $gettok($1-,%currentIndex,44)

    if ($left(%token,1) == #) {
      %token = $remove(%token,1,1)
    }

    %outputTokenList = $addtok(%outputTokenList,%token,44)

    inc %currentIndex

  }

  return %outputTokenList

}

; ------------------------------------------------------------------------------
; Sort CSV tokens alphabetically
; ------------------------------------------------------------------------------

alias sortcsv {

  if (!$1-) {
    return
  }

  return $sorttok($1-,44)

}

; ------------------------------------------------------------------------------
; Add '#' to tokens in CSV (for display)
; ------------------------------------------------------------------------------

alias addHashCSV {

  if ($1 == $null) {
    return
  }

  var %outputTokenList
  var %tokenCount = $numtok($1-,44)
  var %currentIndex = 1

  while (%currentIndex <= %tokenCount) {

    %outputTokenList = %outputTokenList $+ # $+ $gettok($1-,%currentIndex,44)

    if (%currentIndex < %tokenCount) {
      %outputTokenList = %outputTokenList $+ ,
    }

    inc %currentIndex

  }

  return %outputTokenList

}

; ------------------------------------------------------------------------------
; Normalize one channel name for storage/display.
; ------------------------------------------------------------------------------

alias siteinvite_clean_channel {

  var %channel = $1-

  while ($left(%channel,1) == $chr(32)) {
    %channel = $mid(%channel,2)
  }

  while ($right(%channel,1) == $chr(32)) {
    %channel = $left(%channel,$calc($len(%channel)-1))
  }

  ; Store channels without a leading '#'.
  while ($left(%channel,1) == #) {
    %channel = $mid(%channel,2)
  }

  return %channel

}

; ------------------------------------------------------------------------------
; Normalize a channel CSV, including legacy values where two channel rows
; were accidentally concatenated as '#channel1#channel2'.
; ------------------------------------------------------------------------------

alias siteinvite_normalize_channel_csv {

  var %input = $1-
  var %output
  var %i = 1
  var %count = $numtok(%input,44)

  while (%i <= %count) {

    var %token = $siteinvite_clean_channel($gettok(%input,%i,44))

    while ($pos(%token,#,1)) {

      var %hashPos = $pos(%token,#,1)
      var %leftPart = $siteinvite_clean_channel($left(%token,$calc(%hashPos - 1)))
      var %rightPart = $siteinvite_clean_channel($mid(%token,$calc(%hashPos + 1)))

      if (%leftPart) {
        %output = $addtok(%output,%leftPart,44)
      }

      %token = %rightPart

    }

    if (%token) {
      %output = $addtok(%output,%token,44)
    }

    inc %i

  }

  return $sorttok(%output,44)

}

; ------------------------------------------------------------------------------
; Global variables
; ------------------------------------------------------------------------------

var %siteInviteIniPath
var %currentSiteName
var %isCurrentlyLoading
var %siteInvitePendingCurrentSite
var %siteInvitePendingSelectedSite
var %siteInvitePendingSelectedLine

; Buffer variables
var %buf.Settings.Debug
var %buf.Settings.Info
var %buf.Settings.Code
var %buf.Settings.Error
var %buf.Settings.CheckInterval
var %buf.Settings.CheckUser
var %buf.Settings.CheckBot
var %buf.Settings.SyncMode
var %buf.Settings.FlashFXP
var %buf.Settings.BotNick
var %buf.Settings.FTPUser
var %buf.Settings.GlobalNick
var %buf.Settings.FlashAppData
var %buf.Settings.FTPCheck

; Buffer for site data
var %buf.Site.Name
var %buf.Site.BotNick
var %buf.Site.UserNick
var %buf.Site.FTPUser
var %buf.Site.Network
var %buf.Site.Channels
var %buf.Site.Ignore
var %buf.Site.FTPSites
var %buf.Site.FTPSitesIgnore

; ------------------------------------------------------------------------------
; Dialog definition (unchanged)
; ------------------------------------------------------------------------------

dialog siteinviteDialog {

  title "Site Invite Manager"
  size -1 -1 720 480
  option dbu

  box "Settings",900,10 10 700 120
  check "  Debug",1,25 28 40 10
  check "  Info",2,70 28 35 10
  check "  Code",3,105 28 40 10
  check "  Error",4,145 28 40 10

  text "Check interval (min):",18,200 28 65 9
  edit "",19,270 26 40 11,autohs

  text "Check:",5,330 28 25 10
  check " User",6,360 28 35 10
  check " Bot",7,400 28 30 10

  text "Synchronize mode:",12,450 28 55 9
  radio " None",13,510 28 25 9
  radio " All",14,545 28 25 9

  text "Global Nick:",20,25 46 60 9
  edit "",21,90 44 130 11,autohs

  text "Global Bot:",26,235 46 70 9
  edit "",27,310 44 130 11,autohs

  check " Verify target before FTP",22,455 46 105 10

  text "Global FTP-User:",28,25 60 60 9
  edit "",29,90 58 130 11,autohs

  text "FlashFXP Path:",15,25 77 75 9
  edit "",16,110 75 510 11,autohs
  button "...",17,630 75 40 11

  text "FlashFXP Data Path:",23,25 92 85 9
  edit "",24,110 90 510 11,autohs
  button "...",25,630 90 40 11

  text "Config file:",30,25 107 75 9
  edit "",31,110 105 510 11,autohs
  button "...",32,630 105 40 11

  box "Sites",50,10 135 700 335
  list 100,25 155 180 285,vsbar sort check
  button "Add",200,25 443 45 12
  button "Edit",201,75 443 45 12
  button "Delete",202,125 443 50 12
  button "Close",203,630 442 60 14,cancel

  text "Name:",101,220 160 40 9
  edit "",102,275 158 180 11,autohs

  text "User:",103,480 160 35 9
  edit "",108,530 158 130 11,autohs

  text "Network:",105,220 180 50 9
  edit "",106,275 178 180 11,autohs

  text "Bot:",109,480 180 45 9
  edit "",104,530 178 130 11,autohs

  text "FTP-User:",129,220 200 55 9
  edit "",112,275 198 180 11,autohs

  text "Channels:",107,220 225 60 9
  list 110,220 240 220 160,vsbar sort check
  button "Add",113,220 415 45 12
  button "Edit",114,270 415 45 12
  button "Delete",115,320 415 50 12

  text "FTP-Sites:",117,460 225 60 9
  list 120,460 240 220 160,vsbar sort check
  button "Add",123,460 415 45 12
  button "Edit",124,510 415 45 12
  button "Delete",125,560 415 50 12

}

; ------------------------------------------------------------------------------
; Dialog init
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:init:*:{

  set %isCurrentlyLoading 1
  unset %currentSiteName
  unset %buf.Site.*

  did -r siteinviteDialog 102,104,106,108,112,110,120

  var %iniFilePath = $siteinvite_config_path

  set %siteInviteIniPath %iniFilePath

  var %ini = %iniFilePath

  if ($readini(%ini,Settings,Debug) == $null) {
    safeWriteIni %ini Settings Debug 0
  }

  if ($readini(%ini,Settings,Info) == $null) {
    safeWriteIni %ini Settings Info 0
  }

  if ($readini(%ini,Settings,Code) == $null) {
    safeWriteIni %ini Settings Code 0
  }

  if ($readini(%ini,Settings,Error) == $null) {
    safeWriteIni %ini Settings Error 0
  }

  if ($readini(%ini,Settings,CheckInterval) == $null) {
    safeWriteIni %ini Settings CheckInterval 60
  }

  if ($readini(%ini,Settings,CheckUser) == $null) {
    safeWriteIni %ini Settings CheckUser 1
  }

  if ($readini(%ini,Settings,CheckBot) == $null) {
    safeWriteIni %ini Settings CheckBot 1
  }

  if ($readini(%ini,Settings,SyncMode) == $null) {
    safeWriteIni %ini Settings SyncMode 0
  }

  if ($readini(%ini,Settings,FlashFXPPath) == $null) {
    safeWriteIni %ini Settings FlashFXPPath
  }

  if ($readini(%ini,Settings,Nick) == $null) {
    safeWriteIni %ini Settings Nick
  }

  if ($readini(%ini,Settings,BotNick) == $null) {
    safeWriteIni %ini Settings BotNick
  }

  if ($readini(%ini,Settings,FTPUser) == $null) {
    safeWriteIni %ini Settings FTPUser
  }

  if ($readini(%ini,Settings,FlashAppData) == $null) {
    safeWriteIni %ini Settings FlashAppData
  }

  if ($readini(%ini,Settings,FTPCheck) == $null) {
    safeWriteIni %ini Settings FTPCheck 0
  }

  var %displayIniFilePath = $remove(%iniFilePath,$chr(34))
  safeWriteIni %ini Settings ConfigFile %displayIniFilePath

  ; Read into buffer
  set %buf.Settings.Debug $readini(%iniFilePath,Settings,Debug)
  set %buf.Settings.Info $readini(%iniFilePath,Settings,Info)
  set %buf.Settings.Code $readini(%iniFilePath,Settings,Code)
  set %buf.Settings.Error $readini(%iniFilePath,Settings,Error)
  set %buf.Settings.CheckInterval $readini(%iniFilePath,Settings,CheckInterval)
  set %buf.Settings.CheckUser $readini(%iniFilePath,Settings,CheckUser)
  set %buf.Settings.CheckBot $readini(%iniFilePath,Settings,CheckBot)
  set %buf.Settings.SyncMode $readini(%iniFilePath,Settings,SyncMode)
  set %buf.Settings.FlashFXP $readini(%iniFilePath,Settings,FlashFXPPath)
  set %buf.Settings.GlobalNick $readini(%iniFilePath,Settings,Nick)
  set %buf.Settings.BotNick $readini(%iniFilePath,Settings,BotNick)
  set %buf.Settings.FTPUser $readini(%iniFilePath,Settings,FTPUser)
  set %buf.Settings.FlashAppData $readini(%iniFilePath,Settings,FlashAppData)
  set %buf.Settings.FTPCheck $readini(%iniFilePath,Settings,FTPCheck)

  if (%buf.Settings.FTPCheck == $null) {
    set %buf.Settings.FTPCheck 0
  }

  set %siteInviteFTPCheck %buf.Settings.FTPCheck

  ; GUI sync
  if (%buf.Settings.Debug == 1) {
    did -c siteinviteDialog 1
  }

  if (%buf.Settings.Info == 1) {
    did -c siteinviteDialog 2
  }

  if (%buf.Settings.Code == 1) {
    did -c siteinviteDialog 3
  }

  if (%buf.Settings.Error == 1) {
    did -c siteinviteDialog 4
  }

  if (%buf.Settings.CheckUser == 1) {
    did -c siteinviteDialog 6
  }

  if (%buf.Settings.CheckBot == 1) {
    did -c siteinviteDialog 7
  }

  did -ra siteinviteDialog 16 %buf.Settings.FlashFXP
  did -ra siteinviteDialog 21 %buf.Settings.GlobalNick
  did -ra siteinviteDialog 27 %buf.Settings.BotNick
  did -ra siteinviteDialog 29 %buf.Settings.FTPUser
  did -ra siteinviteDialog 24 %buf.Settings.FlashAppData
  did -ra siteinviteDialog 31 %displayIniFilePath
  did -c siteinviteDialog $iif(%buf.Settings.SyncMode == 1,14,13)

  if (%buf.Settings.FTPCheck == 1) {
    did -c siteinviteDialog 22
  }

  ; Populate sites
  did -r siteinviteDialog 100

  var %i = 1

  while ($ini(%iniFilePath,%i)) {

    var %site = $v1

    if (%site != Settings) {

      did -a siteinviteDialog 100 %site

      var %ignore = $readini(%iniFilePath,%site,ignore_entire)
      var %lineNum = $didwm(siteinviteDialog,100,%site)

      ; ignore_entire = 0 means the site is active and checked.
      ; ignore_entire = 1 means the site is inactive and unchecked.
      if (%ignore == 0 || %ignore == $null) {
        did -s siteinviteDialog 100 %lineNum
      } else {
        did -l siteinviteDialog 100 %lineNum
      }
    }

    inc %i

  }

  ; Select and load the first configured site.
  var %firstSite = $did(siteinviteDialog,100,1).text

  if (%buf.Settings.GlobalNick) {
    did -ra siteinviteDialog 108 %buf.Settings.GlobalNick
  } else {
    did -ra siteinviteDialog 108 $me
  }

  if (%firstSite) {
    siteinvite_load %firstSite
  }

  ; Check interval
  var %checkMinutes = $readini(%iniFilePath,Settings,CheckInterval)

  if (%checkMinutes == $null) {

    ; Default value in minutes
    set %checkMinutes 60

    safeWriteIni %iniFilePath Settings CheckInterval %checkMinutes

  }

  ; Set buffer in seconds
  set %buf.Settings.CheckIntervalSeconds $calc(%checkMinutes * 60)

  ; Update the UI
  did -ra siteinviteDialog 19 %checkMinutes

  unset %iniFileMTime
  GetData
  unset %isCurrentlyLoading

}

; ------------------------------------------------------------------------------
; Load selected site data (NOW WITH BUFFER)
; ------------------------------------------------------------------------------

alias siteinvite_load {

  if (!$1) {
    return
  }

  set %currentSiteName $1
  set %isCurrentlyLoading 1

  var %ini = %siteInviteIniPath

  ; Load basic site fields
  set %buf.Site.Name     $iif($readini(%ini,$1,name),$v1,$1)
  set %buf.Site.UserNick $readini(%ini,$1,usernick)
  set %buf.Site.FTPUser  $readini(%ini,$1,ftpuser)
  set %buf.Site.BotNick  $readini(%ini,$1,botnick)
  set %buf.Site.Network  $readini(%ini,$1,network)

  if (!%buf.Site.UserNick) {
    if (%buf.Settings.GlobalNick) {
      set %buf.Site.UserNick %buf.Settings.GlobalNick
    } else {
      set %buf.Site.UserNick $me
    }
  }

  if (!%buf.Site.FTPUser) {
    if (%buf.Settings.FTPUser) {
      set %buf.Site.FTPUser %buf.Settings.FTPUser
    } else {
      set %buf.Site.FTPUser %buf.Site.UserNick
    }
  }

  var %channels = $siteinvite_normalize_channel_csv($readini(%ini,%currentSiteName,channels))
  var %ignore   = $siteinvite_normalize_channel_csv($readini(%ini,%currentSiteName,ignore))
  var %ftps    = $readini(%ini,%currentSiteName,ftpsites)
  var %ftpign = $readini(%ini,%currentSiteName,ftpsites_ignore)

  if (%channels) {
    set %buf.Site.Channels %channels
  } else {
    unset %buf.Site.Channels
  }

  if (%ignore) {
    set %buf.Site.Ignore %ignore
  } else {
    unset %buf.Site.Ignore
  }

  if (%ftps) {
    set %buf.Site.FTPSites %ftps
  } else {
    unset %buf.Site.FTPSites
  }

  if (%ftpign) {
    set %buf.Site.FTPSitesIgnore %ftpign
  } else {
    unset %buf.Site.FTPSitesIgnore
  }

  ; Push loaded buffer state to the dialog
  siteinvite_refresh_ui

  unset %isCurrentlyLoading

}

; ------------------------------------------------------------------------------
; Refresh ui from current buffer (helper alias)
; ------------------------------------------------------------------------------

alias siteinvite_refresh_ui {

  ; Updates active channel/FTP lists and checkbox/edit fields
  did -ra siteinviteDialog 102 %buf.Site.Name
  did -ra siteinviteDialog 108 %buf.Site.UserNick
  did -ra siteinviteDialog 112 %buf.Site.FTPUser
  did -ra siteinviteDialog 106 %buf.Site.Network
  did -ra siteinviteDialog 104 %buf.Site.BotNick

  ; Channels

  set %buf.Site.Channels $siteinvite_normalize_channel_csv(%buf.Site.Channels)
  set %buf.Site.Ignore $siteinvite_normalize_channel_csv(%buf.Site.Ignore)

  did -r siteinviteDialog 110

  if (%buf.Site.Channels) {

    var %c = $numtok(%buf.Site.Channels,44)
    var %i = 1

    while (%i <= %c) {

      var %displayChannel = $gettok(%buf.Site.Channels,%i,44)

      if ($left(%displayChannel,1) != #) {
        %displayChannel = # $+ %displayChannel
      }

      did -a siteinviteDialog 110 %displayChannel

      inc %i

    }

    ; Channels in "ignore" are inactive and must be unchecked.
    var %lineCount = $did(siteinviteDialog,110).lines
    var %lineIndex = 1

    while (%lineIndex <= %lineCount) {

      var %rowText = $did(siteinviteDialog,110,%lineIndex).text
      var %rowClean = $remove(%rowText,#)
      var %isIgnored = 0

      if (%buf.Site.Ignore) {

        var %igncount = $numtok(%buf.Site.Ignore,44)
        var %y = 1

        while (%y <= %igncount) {
          var %ign = $remove($gettok(%buf.Site.Ignore,%y,44),#)

          if ($lower(%rowClean) == $lower(%ign)) {
            %isIgnored = 1
            break
          }

          inc %y

        }
      }

      if (%isIgnored) {
        did -l siteinviteDialog 110 %lineIndex
      } else {
        did -s siteinviteDialog 110 %lineIndex
      }

      inc %lineIndex

    }
  }

  ; Ftp-sites
  did -r siteinviteDialog 120

  if (%buf.Site.FTPSites) {

    var %c = $numtok(%buf.Site.FTPSites,44)
    var %i = 1

    while (%i <= %c) {

      did -a siteinviteDialog 120 $gettok(%buf.Site.FTPSites,%i,44)

      inc %i

    }

    ; FTP entries in "ftpsites_ignore" are inactive and must be unchecked.
    var %lineCount = $did(siteinviteDialog,120).lines
    var %lineIndex = 1

    while (%lineIndex <= %lineCount) {

      var %rowText = $did(siteinviteDialog,120,%lineIndex).text
      var %isIgnored = 0

      if (%buf.Site.FTPSitesIgnore) {

        var %igncount = $numtok(%buf.Site.FTPSitesIgnore,44)
        var %y = 1

        while (%y <= %igncount) {

          var %ign = $gettok(%buf.Site.FTPSitesIgnore,%y,44)

          if ($lower(%rowText) == $lower(%ign)) {
            %isIgnored = 1
            break
          }

          inc %y

        }
      }

      if (%isIgnored) {
        did -l siteinviteDialog 120 %lineIndex
      } else {
        did -s siteinviteDialog 120 %lineIndex
      }

      inc %lineIndex

    }
  }
}

; ------------------------------------------------------------------------------
; Save check interval in settings
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:edit:19:{

  ; Prevent processing while dialog is initializing
  if (%isCurrentlyLoading) {
    return
  }

  ; Get user input from edit box
  var %minutes = $did(19).text

  ; If empty, set a default (e.g., 5 minutes)
  if (%minutes == $null) {

    set %minutes 5

    did -ra siteinviteDialog 19 %minutes

  }

  ; Validate numeric using AdiIRC operator
  if (%minutes !isnum) {

    ; Show a popup message instead of echo
    var %dummy = $input(Input value: check interval must be a number!, o, Check interval)

    ; Reset to previous valid value in buffer, or default 60
    if (%buf.Settings.CheckIntervalSeconds) {
      did -ra siteinviteDialog 19 $calc(%buf.Settings.CheckIntervalSeconds / 60)
    } else {
      did -ra siteinviteDialog 19 60
    }

    return

  }

  ; Buffer: seconds
  set %buf.Settings.CheckInterval %minutes
  set %buf.Settings.CheckIntervalSeconds $calc(%minutes * 60)

  ; Ini: minutes
  var %ini = %siteInviteIniPath

  safeWriteIni %ini Settings CheckInterval %minutes

  ; Apply the new interval immediately
  isCheckTimer

}

on *:DIALOG:siteinviteDialog:sclick:13,14:{

  if (%isCurrentlyLoading) {
    return
  }

  set %buf.Settings.SyncMode $did(14).state

  save_settings

}

; ------------------------------------------------------------------------------
; Save FTP target verification setting
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:22:{

  if (%isCurrentlyLoading) {
    return
  }

  set %buf.Settings.FTPCheck $did(22).state
  set %siteInviteFTPCheck %buf.Settings.FTPCheck

  save_settings

}

; ------------------------------------------------------------------------------
; Save checkboxes in settings - debug / info / code / error / user / bot
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:1,2,3,4,6,7:{

  if (%isCurrentlyLoading) {
    return
  }

  if ($did == 1) {
    set %buf.Settings.Debug $did($did).state
  } elseif ($did == 2) {
    set %buf.Settings.Info $did($did).state
  } elseif ($did == 3) {
    set %buf.Settings.Code $did($did).state
  } elseif ($did == 4) {
    set %buf.Settings.Error $did($did).state
  } elseif ($did == 6) {
    set %buf.Settings.CheckUser $did($did).state
  } elseif ($did == 7) {
    set %buf.Settings.CheckBot $did($did).state
  }

  save_settings

}

; ------------------------------------------------------------------------------
; Save settings to INI
; ------------------------------------------------------------------------------

alias save_settings {

  var %ini = %siteInviteIniPath

  safeWriteIni %ini Settings Debug %buf.Settings.Debug
  safeWriteIni %ini Settings Info %buf.Settings.Info
  safeWriteIni %ini Settings Code %buf.Settings.Code
  safeWriteIni %ini Settings Error %buf.Settings.Error
  safeWriteIni %ini Settings CheckInterval %buf.Settings.CheckInterval
  safeWriteIni %ini Settings CheckUser %buf.Settings.CheckUser
  safeWriteIni %ini Settings CheckBot %buf.Settings.CheckBot
  safeWriteIni %ini Settings FlashFXPPath %buf.Settings.FlashFXP
  safeWriteIni %ini Settings Nick %buf.Settings.GlobalNick
  safeWriteIni %ini Settings BotNick %buf.Settings.BotNick
  safeWriteIni %ini Settings FTPUser %buf.Settings.FTPUser
  safeWriteIni %ini Settings FlashAppData %buf.Settings.FlashAppData
  safeWriteIni %ini Settings FTPCheck %buf.Settings.FTPCheck

  set %siteInviteFTPCheck %buf.Settings.FTPCheck

  safeWriteIni %ini Settings SyncMode %buf.Settings.SyncMode

}

; ------------------------------------------------------------------------------
; Save current site to INI from buffer
; ------------------------------------------------------------------------------

alias siteinvite_save {

  if (!%currentSiteName) {
    return
  }

  var %ini = %siteInviteIniPath

  ; ============================================================
  ; Basic fields
  ; ============================================================

  safeWriteIni %ini %currentSiteName name     %buf.Site.Name
  safeWriteIni %ini %currentSiteName usernick %buf.Site.UserNick
  safeWriteIni %ini %currentSiteName ftpuser  %buf.Site.FTPUser
  safeWriteIni %ini %currentSiteName botnick  %buf.Site.BotNick
  safeWriteIni %ini %currentSiteName network  %buf.Site.Network

  ; ============================================================
  ; Channels
  ; ============================================================

  var %rawChannels = $didtok(siteinviteDialog,110,44)
  var %channels = $siteinvite_normalize_channel_csv(%rawChannels)
  var %ignore
  var %i = 1
  var %lines = $did(siteinviteDialog,110).lines

  while (%i <= %lines) {

    if ($did(siteinviteDialog,110,%i).cstate == 0) {
      var %channel = $siteinvite_clean_channel($did(siteinviteDialog,110,%i).text)
      if (%channel) {
        %ignore = $addtok(%ignore,%channel,44)
      }
    }

    inc %i

  }

  %ignore = $siteinvite_normalize_channel_csv(%ignore)

  if (%channels) {
    safeWriteIni %ini %currentSiteName channels %channels
  } else {
    remini %ini %currentSiteName channels
  }

  if (%ignore) {
    safeWriteIni %ini %currentSiteName ignore %ignore
  } else {
    remini %ini %currentSiteName ignore
  }

  ; ============================================================
  ; Ftp sits
  ; ============================================================

  var %ftps
  var %ftpignore
  var %i = 1
  var %lines = $did(siteinviteDialog,120).lines

  while (%i <= %lines) {

    var %ftp = $did(siteinviteDialog,120,%i).text
    %ftps = $addtok(%ftps,%ftp,44)

    if ($did(siteinviteDialog,120,%i).cstate == 0) {
      %ftpignore = $addtok(%ftpignore,%ftp,44)
    }

    inc %i

  }

  if (%ftps) {
    safeWriteIni %ini %currentSiteName ftpsites %ftps
  } else {
    remini %ini %currentSiteName ftpsites
  }

  if (%ftpignore) {
    safeWriteIni %ini %currentSiteName ftpsites_ignore %ftpignore
  } else {
    remini %ini %currentSiteName ftpsites_ignore
  }

}

; ------------------------------------------------------------------------------
; Save current site and force the INI/main-script cache to refresh.
; ------------------------------------------------------------------------------

alias siteinvite_save_persist {

  siteinvite_save

  var %ini = %siteInviteIniPath

  if ($isfile(%ini)) {
    flushini $qt(%ini)
  }

  ; Force the main script's GetData() to reread the INI after a GUI change.
  unset %iniFileMTime

}

; ------------------------------------------------------------------------------
; Save all site ignore_entire from ui
; ------------------------------------------------------------------------------

alias save_ignore_entire {

  var %ini = %siteInviteIniPath

  if (!$isfile(%ini)) {
    return
  }

  var %i = 1
  var %total = $did(siteinviteDialog,100).lines

  while (%i <= %total) {

    var %site = $did(siteinviteDialog,100,%i).text
    var %c = $did(siteinviteDialog,100,%i).cstate
    var %state = $iif(%c,0,1)

    safeWriteIni %ini %site ignore_entire %state

    inc %i

  }
}

; ------------------------------------------------------------------------------
; Site list click: wait until the listcb checkbox state has settled.
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:100:{

  if (%isCurrentlyLoading) {
    return
  }

  ; AdiIRC documents sclick as the list/check event. The .cstate value has
  ; historically been timing-sensitive here, so process the state after the
  ; GUI event has completed.
  set %siteInvitePendingCurrentSite %currentSiteName
  set %siteInvitePendingSelectedSite $did(siteinviteDialog,100).seltext
  set %siteInvitePendingSelectedLine $did(siteinviteDialog,100).sel

  .timerSiteInviteSiteClick off
  .timerSiteInviteSiteClick -m 1 250 siteinvite_process_site_click

}

; ------------------------------------------------------------------------------
; Process site-list click after the checkbox state has settled.
; ------------------------------------------------------------------------------

alias siteinvite_process_site_click {

  var %oldSite = %siteInvitePendingCurrentSite
  var %newSite = %siteInvitePendingSelectedSite
  var %newLine = %siteInvitePendingSelectedLine

  unset %siteInvitePendingCurrentSite
  unset %siteInvitePendingSelectedSite
  unset %siteInvitePendingSelectedLine

  if (!%newSite || !%newLine) {
    return
  }

  ; Save the exact state of the row that was clicked.
  var %checked = $did(siteinviteDialog,100,%newLine).cstate
  var %ignoreState = $iif(%checked,0,1)
  safeWriteIni %siteInviteIniPath %newSite ignore_entire %ignoreState

  ; Save the site whose fields are currently displayed before switching away.
  if (%oldSite) {
    siteinvite_save_persist
  } else {
    flushini $qt(%siteInviteIniPath)
    unset %iniFileMTime
  }

  ; Load the newly selected site only after its own active/inactive state is
  ; already persisted.
  if ($lower(%newSite) != $lower(%oldSite)) {
    siteinvite_load %newSite
  }

}

; ------------------------------------------------------------------------------
; Persist channel and FTP-site checkbox state after the list click has settled.
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:110,120:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  ; Give AdiIRC time to finish the checkbox state change before reading cstate.
  .timerSiteInviteListSave off
  .timerSiteInviteListSave -m 1 250 siteinvite_save_persist

}

; ------------------------------------------------------------------------------
; Create new site (add to list and create empty buffer — do not write to ini)
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:200:{

  var %newSiteName = $input(Enter new site name:,e)

  if (!%newSiteName) {
    return
  }

  ; Check that it doesn't already exist in the listbox
  var %lines = $did(siteinviteDialog,100).lines

  var %i = 1

  while (%i <= %lines) {

    if ($did(siteinviteDialog,100,%i).text == %newSiteName) {

      noop $input(Site: %newSiteName already exists! $crlf $crlf $crlf,i)
      return

    }

    inc %i

  }

  ; Add to listbox (locally), mark it active and create empty buffer for it
  did -a siteinviteDialog 100 %newSiteName
  did -s siteinviteDialog 100 $did(siteinviteDialog,100).lines

  ; Save current site to buffer before we switch (if one was selected)
  if (%currentSiteName) {

    ; Same logic as in select-handler
    set %buf.Site.Name $did(siteinviteDialog,102).text
    set %buf.Site.UserNick $did(siteinviteDialog,108).text
    set %buf.Site.FTPUser $did(siteinviteDialog,112).text
    set %buf.Site.BotNick $did(siteinviteDialog,104).text
    set %buf.Site.Network $did(siteinviteDialog,106).text

    ; Channel save rows

    var %lines = $did(siteinviteDialog,110).lines

    if (%lines) {

      var %jc = 1
      var %chans

      while (%jc <= %lines) {

        var %txt = $did(siteinviteDialog,110,%jc).text
        var %clean = $siteinvite_clean_channel(%txt)

        %chans = $addtok(%chans,%clean,44)

        inc %jc

      }

      set %buf.Site.Channels $sortcsv(%chans)

    } else {

      unset %buf.Site.Channels

    }

    ; Build ignore from unchecked rows (inactive channels).
    var %ignore
    var %ignoreIndex = 1
    var %ignoreLines = $did(siteinviteDialog,110).lines

    while (%ignoreIndex <= %ignoreLines) {
      if ($did(siteinviteDialog,110,%ignoreIndex).cstate == 0) {

        var %ignoreText = $siteinvite_clean_channel($did(siteinviteDialog,110,%ignoreIndex).text)

        %ignore = $addtok(%ignore,%ignoreText,44)

      }

      inc %ignoreIndex

    }

    if (%ignore) {
      set %buf.Site.Ignore $sortcsv(%ignore)
    } else {
      unset %buf.Site.Ignore
    }

    ; Build ftpsites
    var %lines = $did(siteinviteDialog,120).lines

    if (%lines) {

      var %jc = 1
      var %ftps

      while (%jc <= %lines) {

        var %txt = $did(siteinviteDialog,120,%jc).text

        %ftps = $addtok(%ftps,%txt,44)

        inc %jc

      }

      set %buf.Site.FTPSites $sortcsv(%ftps)

    } else {

      unset %buf.Site.FTPSites

    }

    ; Build ftpsites_ignore from unchecked rows (inactive FTP-sites).
    var %ftpIgnore
    var %ftpIgnoreIndex = 1
    var %ftpIgnoreLines = $did(siteinviteDialog,120).lines

    while (%ftpIgnoreIndex <= %ftpIgnoreLines) {
      if ($did(siteinviteDialog,120,%ftpIgnoreIndex).cstate == 0) {

        var %ftpIgnoreText = $did(siteinviteDialog,120,%ftpIgnoreIndex).text

        %ftpIgnore = $addtok(%ftpIgnore,%ftpIgnoreText,44)

      }

      inc %ftpIgnoreIndex

    }

    if (%ftpIgnore) {
      set %buf.Site.FTPSitesIgnore $sortcsv(%ftpIgnore)
    } else {
      unset %buf.Site.FTPSitesIgnore
    }

    siteinvite_save

  }

  ; Set buffer for new site (empty)
  set %currentSiteName %newSiteName
  set %buf.Site.Name %newSiteName

  if (%buf.Settings.GlobalNick) {
    set %buf.Site.UserNick %buf.Settings.GlobalNick
  } else {
    set %buf.Site.UserNick $me
  }

  if (%buf.Settings.FTPUser) {
    set %buf.Site.FTPUser %buf.Settings.FTPUser
  } else {
    set %buf.Site.FTPUser %buf.Site.UserNick
  }

  unset %buf.Site.BotNick
  unset %buf.Site.FTPUser
  unset %buf.Site.Network
  unset %buf.Site.Channels
  unset %buf.Site.Ignore
  unset %buf.Site.FTPSites
  unset %buf.Site.FTPSitesIgnore

  ; Show in ui
  siteinvite_refresh_ui
  siteinvite_save

}

; ------------------------------------------------------------------------------
; Edit site name (saves only in memory), ini-fix on close
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:201:{

  var %selectedSiteName = $did(siteinviteDialog,100).seltext

  if (!%selectedSiteName) {

    noop $input(Select a site to edit first!,o)
    return

  }

  var %newname = $input(Enter new name for site %selectedSiteName $+ :,e,Rename site,%selectedSiteName)

  ; Check if the user typed the same name
  if (%newname == %selectedSiteName) {

    noop $input(You cannot rename the site to the same name!,o,Error!)
    return

  }

  if (!%newname) || (%newname == %selectedSiteName) {
    return
  }

  ; Check if new name already exists
  var %i = 1

  while (%i <= $did(siteinviteDialog,100).lines) {

    if ($did(siteinviteDialog,100,%i).text == %newname) {

      noop $input(Site "%newname" already exists!,o)
      return

    }

    inc %i

  }

  ; Save current site to buffer (exactly as in add)
  if (%currentSiteName) {

    set %buf.Site.Name $did(siteinviteDialog,102).text
    set %buf.Site.UserNick $did(siteinviteDialog,108).text
    set %buf.Site.FTPUser $did(siteinviteDialog,112).text
    set %buf.Site.BotNick $did(siteinviteDialog,104).text
    set %buf.Site.Network $did(siteinviteDialog,106).text

    ; Channel save rows
    var %lines = $did(siteinviteDialog,110).lines

    if (%lines) {

      var %jc = 1
      var %chans

      while (%jc <= %lines) {

        %chans = $addtok(%chans,$remove($did(siteinviteDialog,110,%jc).text,#),44)

        inc %jc

      }

      set %buf.Site.Channels $sortcsv(%chans)

    } else {

      unset %buf.Site.Channels

    }

    ; Build ignore from unchecked rows (inactive channels).
    var %ignore
    var %ignoreIndex = 1
    var %ignoreLines = $did(siteinviteDialog,110).lines

    while (%ignoreIndex <= %ignoreLines) {
      if ($did(siteinviteDialog,110,%ignoreIndex).cstate == 0) {

        var %ignoreText = $siteinvite_clean_channel($did(siteinviteDialog,110,%ignoreIndex).text)

        %ignore = $addtok(%ignore,%ignoreText,44)

      }

      inc %ignoreIndex

    }

    if (%ignore) {
      set %buf.Site.Ignore $sortcsv(%ignore)
    } else {
      unset %buf.Site.Ignore
    }

    ; Build ftpsites
    var %lines = $did(siteinviteDialog,120).lines

    if (%lines) {

      var %jc = 1
      var %ftps

      while (%jc <= %lines) {

        %ftps = $addtok(%ftps,$did(siteinviteDialog,120,%jc).text,44)
        inc %jc

      }

      set %buf.Site.FTPSites $sortcsv(%ftps)

    } else {

      unset %buf.Site.FTPSites

    }

    ; Build ftpsites_ignore from unchecked rows (inactive FTP-sites).
    var %ftpIgnore
    var %ftpIgnoreIndex = 1
    var %ftpIgnoreLines = $did(siteinviteDialog,120).lines

    while (%ftpIgnoreIndex <= %ftpIgnoreLines) {
      if ($did(siteinviteDialog,120,%ftpIgnoreIndex).cstate == 0) {
        var %ftpIgnoreText = $did(siteinviteDialog,120,%ftpIgnoreIndex).text
        %ftpIgnore = $addtok(%ftpIgnore,%ftpIgnoreText,44)
      }

      inc %ftpIgnoreIndex

    }

    if (%ftpIgnore) {
      set %buf.Site.FTPSitesIgnore $sortcsv(%ftpIgnore)
    } else {
      unset %buf.Site.FTPSitesIgnore
    }

    siteinvite_save

  }

  ; Preserve check state
  var %selindex = $did(siteinviteDialog,100).sel
  var %oldcheck = $did(siteinviteDialog,100,%selindex).cstate

  ; Change name in listbox
  did -d siteinviteDialog 100 %selindex
  did -i siteinviteDialog 100 %selindex %newname

  if (%oldcheck == 1) {
    did -s siteinviteDialog 100 %selindex
  }

  ; Update current if it was the active site
  if (%currentSiteName == %selectedSiteName) {

    set %currentSiteName %newname
    set %buf.Site.Name %newname

    did -ra siteinviteDialog 102 %newname

  }

  ; Rename in ini immediately
  var %ini = %siteInviteIniPath
  var %k = 1

  while ($ini(%ini,%selectedSiteName,%k)) {

    var %key = $v1
    var %val = $readini(%ini,%selectedSiteName,%key)

    safeWriteIni %ini %newname %key %val

    inc %k

  }

  remini %ini %selectedSiteName

  save_ignore_entire

}

; ------------------------------------------------------------------------------
; Delete selected site (remove only from list and in-mem buffer; remove ini first on close)
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:202:{

  var %selectedSiteName = $did(siteinviteDialog,100).seltext

  if (%selectedSiteName && $input(Delete site %selectedSiteName $+ ? This cannot be undone. $crlf $crlf $crlf,yq,Delete site?)) {

    ; If it's the current site, clear buffer
    if (%currentSiteName && (%currentSiteName == %selectedSiteName)) {

      unset %buf.Site.Name
      unset %buf.Site.UserNick
      unset %buf.Site.FTPUser
      unset %buf.Site.BotNick
      unset %buf.Site.Network
      unset %buf.Site.Channels
      unset %buf.Site.Ignore
      unset %buf.Site.FTPSites
      unset %buf.Site.FTPSitesIgnore
      unset %currentSiteName

    }

    ; Remove from listbox (but INI will be updated first on close)
    did -d siteinviteDialog 100 $did(siteinviteDialog,100).sel
    did -r siteinviteDialog 102,104,106,108,112,110,120

    ; Remove from INI immediately
    var %ini = %siteInviteIniPath

    remini %ini %selectedSiteName

  }

  if (!$did(siteinviteDialog,100).lines) || (!$did(siteinviteDialog,100).sel) {

    unset %currentSiteName
    unset %buf.Site.*

    did -r siteinviteDialog 102,104,106,108,112,110,120

  }

}

; ------------------------------------------------------------------------------
; Add new channel (updates only the buffer)
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:113:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  var %rawInputString = $input(The channel MUST start with #,e)

  if (!%rawInputString) {
    return
  }

  ; Trim whitespace
  var %trimmedInputString = %rawInputString

  while ($left(%trimmedInputString,1) == $chr(32)) {
    %trimmedInputString = $mid(%trimmedInputString,2)
  }

  while ($right(%trimmedInputString,1) == $chr(32)) {
    %trimmedInputString = $left(%trimmedInputString,$calc($len(%trimmedInputString)-1))
  }

  if ($asc($left(%trimmedInputString,1)) != 35) {

    noop $input(You wrote: %trimmedInputString $+ $crlf $+ $crlf $+ It MUST begin with $chr(35),o,Error!)
    return

  }

  var %channelName = %trimmedInputString

  while ($left(%channelName,1) == $chr(32)) {
    %channelName = $mid(%channelName,2)
  }

  while ($right(%channelName,1) == $chr(32)) {
    %channelName = $left(%channelName,$calc($len(%channelName)-1))
  }

  ; Normalized list from buffer
  var %rawChannelString = %buf.Site.Channels
  var %normalizedChannelList
  var %i = 1
  var %tokenCount = $numtok(%rawChannelString,44)

  while (%i <= %tokenCount) {

    var %token = $gettok(%rawChannelString,%i,44)

    while ($left(%token,1) == $chr(32)) {
      %token = $mid(%token,2)
    }

    while ($right(%token,1) == $chr(32)) {
      %token = $left(%token,$calc($len(%token)-1))
    }

    %normalizedChannelList = $addtok(%normalizedChannelList,%token,44)

    inc %i

  }

  if ($istok(%normalizedChannelList,$siteinvite_clean_channel(%channelName),44)) {

    noop $input(Channel: %channelName already exists! $crlf $crlf $crlf,i)
    return

  }

  var %newRawChannelList

  if (%rawChannelString) {
    %newRawChannelList = %rawChannelString $+ , $+ $siteinvite_clean_channel(%channelName)
  } else {
    %newRawChannelList = $siteinvite_clean_channel(%channelName)
  }

  var %sortedNormalizedChannels = $sortcsv(%newRawChannelList)

  set %buf.Site.Channels %sortedNormalizedChannels

  ; New channels start active, so they must not exist in the inactive list.
  set %buf.Site.Ignore $sortcsv($remtok(%buf.Site.Ignore,$siteinvite_clean_channel(%channelName),1,44))

  ; Update ui from buffer
  siteinvite_refresh_ui

  ; Select the new channel in list
  var %lineCount = $did(siteinviteDialog,110).lines
  var %lineIndex = 1

  while (%lineIndex <= %lineCount) {

    if ($did(siteinviteDialog,110,%lineIndex).text == # $+ $siteinvite_clean_channel(%channelName)) {

      did -s siteinviteDialog 110 %lineIndex
      break

    }

    inc %lineIndex

  }

  siteinvite_save

}

; ------------------------------------------------------------------------------
; Edit selected channel (updates buffer)
; ------------------------------------------------------------------------------

;  if (!$input(Delete channel: %selectedLine $+ ? $crlf $crlf $crlf,yq,Confirm)) {
;    return
;  }

on *:DIALOG:siteinviteDialog:sclick:114:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  ; Get selected row
  var %sel = $did(siteinviteDialog,110).sel

  if (!%sel) {
    return
  }

  ; Get old channel name WITH #
  var %oldChannelWithHash = $did(siteinviteDialog,110,%sel).text
  var %wasChecked = $did(siteinviteDialog,110,%sel).cstate

  ; Input dialog pre-filled
  var %newChannelWithHash = $input(Edit channel name:,e,,Edit Channel,%oldChannelWithHash)

  ; Trim spaces/newlines
  while ($left(%newChannelWithHash,1) == $chr(32) || $left(%newChannelWithHash,1) == $chr(13) || $left(%newChannelWithHash,1) == $chr(10)) {
    %newChannelWithHash = $mid(%newChannelWithHash,2)
  }

  while ($right(%newChannelWithHash,1) == $chr(32) || $right(%newChannelWithHash,1) == $chr(13) || $right(%newChannelWithHash,1) == $chr(10)) {
    %newChannelWithHash = $left(%newChannelWithHash,$calc($len(%newChannelWithHash)-1))
  }

  ; Must start with #
  if ($left(%newChannelWithHash,1) != $chr(35)) {

    noop $input(You wrote: %newChannelWithHash $+ $crlf $+ $crlf $+ It MUST begin with $chr(35),o,Error!)
    return

  }

  ; Clean names without # for storage
  var %oldChannel = $siteinvite_clean_channel(%oldChannelWithHash)
  var %newChannel = $siteinvite_clean_channel(%newChannelWithHash)

  ; Prepare clean list for duplicate check
  var %cleanRaw
  var %count = $numtok(%buf.Site.Channels,44)
  var %i = 1

  while (%i <= %count) {

    var %tok = $gettok(%buf.Site.Channels,%i,44)

    %tok = $remove(%tok,#)

    while ($left(%tok,1) == $chr(32)) {
      %tok = $mid(%tok,2)
    }

    while ($right(%tok,1) == $chr(32)) {
      %tok = $left(%tok,$calc($len(%tok)-1))
    }

    %cleanRaw = $addtok(%cleanRaw,%tok,44)

    inc %i

  }

  ; Check if the user typed the same name
  if (%newChannel == %oldChannel) {

    noop $input(You cannot rename the channel to the same name!,o,Error!)
    return

  }

  ; Check duplicate early
  if ($istok(%cleanRaw,%newChannel,44)) {

    noop $input(# $+ The channel %newChannel already exists in the list!,o,Error!)
    return

  }

  ; Rebuild channel list
  var %newList

  %i = 1

  while (%i <= %count) {

    var %tok = $gettok(%buf.Site.Channels,%i,44)

    ; Trim each token
    while ($left(%tok,1) == $chr(32) || $left(%tok,1) == $chr(13) || $left(%tok,1) == $chr(10)) {
      %tok = $mid(%tok,2)
    }

    while ($right(%tok,1) == $chr(32) || $right(%tok,1) == $chr(13) || $right(%tok,1) == $chr(10)) {
      %tok = $left(%tok,$calc($len(%tok)-1))
    }

    if (%tok == %oldChannel) {
      %newList = $addtok(%newList,%newChannel,44)
    } else {
      %newList = $addtok(%newList,%tok,44)
    }

    inc %i

  }

  set %buf.Site.Channels $siteinvite_normalize_channel_csv(%newList)

  ; Keep the inactive-channel list synchronized after a rename.
  if (%wasChecked == 1) {

    ; The renamed channel is active, so it must not exist in "ignore".
    set %buf.Site.Ignore $sortcsv($remtok(%buf.Site.Ignore,%oldChannel,1,44))

  } else {

    ; The renamed channel is inactive, so replace the old entry in "ignore".
    var %ignore = $remtok(%buf.Site.Ignore,%oldChannel,1,44)
    %ignore = $addtok(%ignore,%newChannel,44)

    set %buf.Site.Ignore $sortcsv(%ignore)

  }

  siteinvite_refresh_ui
  siteinvite_save

}

; ------------------------------------------------------------------------------
; Delete selected channel - 100% case-insensitive + perfect sync
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:115:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  var %selectedLine = $did(siteinviteDialog,110).seltext

  if (!%selectedLine) {
    return
  }

  if (!$input(Delete channel: %selectedLine $+ ? $crlf $crlf $crlf,yq,Confirm)) {
    return
  }

  var %cleaned = $siteinvite_clean_channel(%selectedLine)

  ; Remove from regular channels (with trim)
  var %raw = %buf.Site.Channels
  var %newList
  var %i = 1
  var %count = $numtok(%raw,44)

  while (%i <= %count) {

    var %token = $gettok(%raw,%i,44)

    while ($left(%token,1) == $chr(32)) {
      %token = $mid(%token,2)
    }

    while ($right(%token,1) == $chr(32)) {
      %token = $left(%token,$calc($len(%token)-1))
    }

    if ($lower(%token) != $lower(%cleaned)) {
      %newList = $addtok(%newList,%token,44)
    }

    inc %i

  }

  set %buf.Site.Channels $siteinvite_normalize_channel_csv(%newList)

  ; Remove from ignore if it exists (case-insensitive)
  if (%buf.Site.Ignore) {

    var %newIgnoreList
    var %j = 1
    var %ignoreCount = $numtok(%buf.Site.Ignore,44)

    while (%j <= %ignoreCount) {

      var %ignToken = $gettok(%buf.Site.Ignore,%j,44)

      while ($left(%ignToken,1) == $chr(32)) {
        %ignToken = $mid(%ignToken,2)
      }

      while ($right(%ignToken,1) == $chr(32)) {
        %ignToken = $left(%ignToken,$calc($len(%ignToken)-1))
      }

      if ($lower(%ignToken) != $lower(%cleaned)) {
        %newIgnoreList = $addtok(%newIgnoreList,%ignToken,44)
      }

      inc %j

    }

    set %buf.Site.Ignore $sortcsv(%newIgnoreList)

  }

  ; Complete case-insensitive sync, clean ignore from channels that don't exist in channels
  if (%buf.Site.Ignore) && (%buf.Site.Channels) {

    var %cleanignore
    var %k = 1

    while ($gettok(%buf.Site.Ignore,%k,44)) {

      var %ign = $gettok(%buf.Site.Ignore,%k,44)

      ; Trim first
      while ($left(%ign,1) == $chr(32)) {
        %ign = $mid(%ign,2)
      }

      while ($right(%ign,1) == $chr(32)) {
        %ign = $left(%ign,$calc($len(%ign)-1))
      }

      ; Case-insensitive search in Channels
      var %found = $false
      var %m = 1
      var %chanCount = $numtok(%buf.Site.Channels,44)

      while (%m <= %chanCount) {

        var %chan = $gettok(%buf.Site.Channels,%m,44)

        while ($left(%chan,1) == $chr(32)) {
          %chan = $mid(%chan,2)
        }

        while ($right(%chan,1) == $chr(32)) {
          %chan = $left(%chan,$calc($len(%chan)-1))
        }

        if ($lower(%chan) == $lower(%ign)) {

          %found = $true
          break

        }

        inc %m

      }

      if (%found) {
        %cleanignore = $addtok(%cleanignore,%ign,44)
      }

      inc %k

    }

    set %buf.Site.Ignore $sortcsv(%cleanignore)

  } elseif (!%buf.Site.Channels) {

    unset %buf.Site.Ignore

  }

  siteinvite_refresh_ui
  siteinvite_save

}

; ------------------------------------------------------------------------------
; Add new ftp-site
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:123:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  var %rawInputString = $input(Enter FTP-Site name:,e)

  if (!%rawInputString) {
    return
  }

  ; Trim whitespace
  var %trimmedInputString = %rawInputString

  while ($left(%trimmedInputString,1) == $chr(32)) {
    %trimmedInputString = $mid(%trimmedInputString,2)
  }

  while ($right(%trimmedInputString,1) == $chr(32)) {
    %trimmedInputString = $left(%trimmedInputString,$calc($len(%trimmedInputString)-1))
  }

  var %ftpName = %trimmedInputString

  ; Normalized list from buffer
  var %rawFTPString = %buf.Site.FTPSites
  var %normalizedFTPList
  var %i = 1
  var %tokenCount = $numtok(%rawFTPString,44)

  while (%i <= %tokenCount) {

    var %token = $gettok(%rawFTPString,%i,44)

    while ($left(%token,1) == $chr(32)) {
      %token = $mid(%token,2)
    }

    while ($right(%token,1) == $chr(32)) {
      %token = $left(%token,$calc($len(%token)-1))
    }

    %normalizedFTPList = $addtok(%normalizedFTPList,%token,44)

    inc %i

  }

  if ($istok(%normalizedFTPList,%ftpName,44)) {

    noop $input(Site: %ftpName already exists! $crlf $crlf $crlf,i)
    return

  }

  var %newRawFTPList

  if (%rawFTPString) {
    %newRawFTPList = %rawFTPString $+ , $+ %ftpName
  } else {
    %newRawFTPList = %ftpName
  }

  var %sortedNormalizedFTP = $sortcsv(%newRawFTPList)

  set %buf.Site.FTPSites %sortedNormalizedFTP

  ; New FTP-sites start active, so they must not exist in the inactive list.
  set %buf.Site.FTPSitesIgnore $sortcsv($remtok(%buf.Site.FTPSitesIgnore,%ftpName,1,44))

  ; Update ui from buffer
  siteinvite_refresh_ui

  ; Select the new ftp-site in list
  var %lineCount = $did(siteinviteDialog,120).lines
  var %lineIndex = 1

  while (%lineIndex <= %lineCount) {

    if ($did(siteinviteDialog,120,%lineIndex).text == %ftpName) {

      did -s siteinviteDialog 120 %lineIndex
      break

    }

    inc %lineIndex

  }

  siteinvite_save

}

; ------------------------------------------------------------------------------
; Edit selected FTP-Site
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:124:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  var %selectedLine = $did(siteinviteDialog,120).sel

  if (!%selectedLine) {
    return
  }

  var %oldFTPName = $did(siteinviteDialog,120).seltext
  var %wasChecked = $did(siteinviteDialog,120,%selectedLine).cstate
  var %newFTPInput = $input(Edit site: %oldFTPName,e,Rename site)

  if (!%newFTPInput) {
    return
  }

  ; Trim whitespace
  var %trimmedNew = %newFTPInput

  while ($left(%trimmedNew,1) == $chr(32)) {
    %trimmedNew = $mid(%trimmedNew,2)
  }

  while ($right(%trimmedNew,1) == $chr(32)) {
    %trimmedNew = $left(%trimmedNew,$calc($len(%trimmedNew)-1))
  }

  var %newName = %trimmedNew
  var %rawFTPString = %buf.Site.FTPSites
  var %newRawList
  var %i = 1
  var %count = $numtok(%rawFTPString,44)

  ; Check if the user typed the same name
  if (%newName == %oldFTPName) {
    noop $input(You cannot rename the site to the same name!,o,Error!)
    return
  }

  while (%i <= %count) {

    var %token = $gettok(%rawFTPString,%i,44)

    while ($left(%token,1) == $chr(32)) {
      %token = $mid(%token,2)
    }

    while ($right(%token,1) == $chr(32)) {
      %token = $left(%token,$calc($len(%token)-1))
    }

    if (%token != %oldFTPName) {
      %newRawList = $addtok(%newRawList,%token,44)
    }

    inc %i

  }

  ; Add updated
  %newRawList = $addtok(%newRawList,%newName,44)

  var %sortedList = $sortcsv(%newRawList)

  set %buf.Site.FTPSites %sortedList

  ; Keep the inactive FTP-site list synchronized after a rename.
  if (%wasChecked == 1) {

    ; The renamed FTP-site is active, so it must not exist in "ftpsites_ignore".
    set %buf.Site.FTPSitesIgnore $sortcsv($remtok(%buf.Site.FTPSitesIgnore,%oldFTPName,1,44))

  } else {

    ; The renamed FTP-site is inactive, so replace the old entry in "ftpsites_ignore".
    var %newIgnore = $remtok(%buf.Site.FTPSitesIgnore,%oldFTPName,1,44)
    %newIgnore = $addtok(%newIgnore,%newName,44)

    set %buf.Site.FTPSitesIgnore $sortcsv(%newIgnore)

  }

  ; Refresh ui
  siteinvite_refresh_ui
  siteinvite_save

}

; ------------------------------------------------------------------------------
; Delete selected FTP-Site
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:125:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  var %selectedLine = $did(siteinviteDialog,120).seltext

  if (!%selectedLine) {
    return
  }

  if (!$input(Delete site: %selectedLine $+ ? $crlf $crlf $crlf,yq,Confirm)) {
    return
  }

  var %cleaned = %selectedLine

  ; Remove from ftpsites (with trim)
  var %raw = %buf.Site.FTPSites
  var %newList
  var %i = 1
  var %count = $numtok(%raw,44)

  while (%i <= %count) {

    var %token = $gettok(%raw,%i,44)

    while ($left(%token,1) == $chr(32)) {
      %token = $mid(%token,2)
    }

    while ($right(%token,1) == $chr(32)) {
      %token = $left(%token,$calc($len(%token)-1))
    }

    if ($lower(%token) != $lower(%cleaned)) {
      %newList = $addtok(%newList,%token,44)
    }

    inc %i

  }

  set %buf.Site.FTPSites $sortcsv(%newList)

  ; Remove from ftpsites_ignore if it exists (case-insensitive)
  if (%buf.Site.FTPSitesIgnore) {

    var %newIgnoreList
    var %j = 1
    var %ignoreCount = $numtok(%buf.Site.FTPSitesIgnore,44)

    while (%j <= %ignoreCount) {

      var %ignToken = $gettok(%buf.Site.FTPSitesIgnore,%j,44)

      while ($left(%ignToken,1) == $chr(32)) {
        %ignToken = $mid(%ignToken,2)
      }

      while ($right(%ignToken,1) == $chr(32)) {
        %ignToken = $left(%ignToken,$calc($len(%ignToken)-1))
      }

      if ($lower(%ignToken) != $lower(%cleaned)) {
        %newIgnoreList = $addtok(%newIgnoreList,%ignToken,44)
      }

      inc %j

    }

    set %buf.Site.FTPSitesIgnore $sortcsv(%newIgnoreList)

  }

  ; Complete case-insensitive sync, clean ignore from ftpsites that don't exist in ftpsites
  if (%buf.Site.FTPSitesIgnore) && (%buf.Site.FTPSites) {

    var %cleanignore
    var %k = 1

    while ($gettok(%buf.Site.FTPSitesIgnore,%k,44)) {

      var %ign = $gettok(%buf.Site.FTPSitesIgnore,%k,44)

      ; Trim first
      while ($left(%ign,1) == $chr(32)) {
        %ign = $mid(%ign,2)
      }

      while ($right(%ign,1) == $chr(32)) {
        %ign = $left(%ign,$calc($len(%ign)-1))
      }

      ; Case-insensitive search in ftpsites
      var %found = $false
      var %m = 1
      var %chanCount = $numtok(%buf.Site.FTPSites,44)

      while (%m <= %chanCount) {

        var %chan = $gettok(%buf.Site.FTPSites,%m,44)

        while ($left(%chan,1) == $chr(32)) {
          %chan = $mid(%chan,2)
        }

        while ($right(%chan,1) == $chr(32)) {
          %chan = $left(%chan,$calc($len(%chan)-1))
        }

        if ($lower(%chan) == $lower(%ign)) {

          %found = $true
          break

        }

        inc %m

      }

      if (%found) {
        %cleanignore = $addtok(%cleanignore,%ign,44)
      }

      inc %k

    }

    set %buf.Site.FTPSitesIgnore $sortcsv(%cleanignore)

  } elseif (!%buf.Site.FTPSites) {
    unset %buf.Site.FTPSitesIgnore
  }

  siteinvite_refresh_ui
  siteinvite_save

}

; ------------------------------------------------------------------------------
; Save basic fields (name, botnick, network), only buffer update
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:edit:*:{

  if (%isCurrentlyLoading) {
    return
  }

  var %id = $did
  var %text = $did($dname,$did).text

  ; Global settings must be handled before the current-site guard.
  ; They are independent of site selection.
  if (%id == 21) {
    set %buf.Settings.GlobalNick %text
    save_settings
    return

  } elseif (%id == 27) {

    set %buf.Settings.BotNick %text
    save_settings
    return

  } elseif (%id == 29) {

    set %buf.Settings.FTPUser %text
    save_settings
    return

  }

  if (!%currentSiteName) {
    return
  }

  if (%id == 102) {
    set %buf.Site.Name %text
  } elseif (%id == 108) {
    set %buf.Site.UserNick %text
  } elseif (%id == 112) {
    set %buf.Site.FTPUser %text
  } elseif (%id == 104) {
    set %buf.Site.BotNick %text
  } elseif (%id == 106) {
    set %buf.Site.Network %text
  }

  siteinvite_save

}

; ------------------------------------------------------------------------------
; Save FlashFXP data path
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:edit:24:{

  if (%isCurrentlyLoading) {
    return
  }

  set %buf.Settings.FlashAppData $did(siteinviteDialog,24).text
  save_settings

}

; ------------------------------------------------------------------------------
; Browse flashfxp path (updates buffer)
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:17:{

  var %path = $sfile(Select FlashFXP executable,FlashFXP.exe)

  if (%path) {

    did -ra siteinviteDialog 16 %path
    set %buf.Settings.FlashFXP %path
    save_settings

  }

}

; ------------------------------------------------------------------------------
; Browse FlashFXP data directory
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:25:{

  var %path = $sdir(Select FlashFXP data directory)

  if (%path) {

    did -ra siteinviteDialog 24 %path
    set %buf.Settings.FlashAppData %path
    save_settings

  }
}

; ------------------------------------------------------------------------------
; Select the SiteInvite configuration file
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:32:{

  var %newIniFilePath = $sfile(Select configuration file,*.ini)

  if (%newIniFilePath) {
    siteinvite_activate_config %newIniFilePath
  }
}

on *:DIALOG:siteinviteDialog:edit:31:{

  if (%isCurrentlyLoading) {
    return
  }

  var %newIniFilePath = $did(siteinviteDialog,31).text

  if ($lower($right(%newIniFilePath,4)) != .ini) {
    return
  }

  if (!$pos(%newIniFilePath,$chr(92),1) && !$pos(%newIniFilePath,/,1)) {
    %newIniFilePath = $scriptdir $+ %newIniFilePath
  }

  siteinvite_activate_config %newIniFilePath

}

alias siteinvite_activate_config {

  var %newIniFilePath = $1-
  var %currentIniFilePath = $remove(%siteInviteIniPath,$chr(34))

  if (%newIniFilePath == %currentIniFilePath) {
    return
  }

  set %iniFilePath $qt(%newIniFilePath)
  set %siteInviteConfigPath %iniFilePath
  unset %iniFileMTime

  ; Closing saves the current file before reopening the selected configuration.
  dialog -x siteinviteDialog
  dialog -m siteinviteDialog siteinviteDialog

}

; ------------------------------------------------------------------------------
; Double-click site to open in flashfxp (no change)
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:dclick:100:{

  var %selectedSiteName = $did(siteinviteDialog,100).seltext
  var %flashFXPExecutablePath = $did(siteinviteDialog,16).text

  if (%selectedSiteName && $isfile(%flashFXPExecutablePath)) {
    run $qt(%flashFXPExecutablePath) -c %selectedSiteName
  } elseif (%selectedSiteName) {
    noop $input(FlashFXP path not set or executable not found!,o,Error)
  }
}

; ------------------------------------------------------------------------------
; close event, here everything is saved to ini
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:close:*:{

  var %ini = %siteInviteIniPath

  ; -------------------------------------------------------------
  ; Save settings from buffer
  ; -------------------------------------------------------------

  save_settings

  ; -------------------------------------------------------------
  ; Update buffer for current site from ui
  ; -------------------------------------------------------------

  if (%currentSiteName) {

    set %buf.Site.Name $did(siteinviteDialog,102).text
    set %buf.Site.UserNick $did(siteinviteDialog,108).text
    set %buf.Site.FTPUser $did(siteinviteDialog,112).text
    set %buf.Site.BotNick $did(siteinviteDialog,104).text
    set %buf.Site.Network $did(siteinviteDialog,106).text

    ; Build channels and inactive-channel list from the actual listcb rows.
    var %rawChannels = $didtok(siteinviteDialog,110,44)
    set %buf.Site.Channels $siteinvite_normalize_channel_csv(%rawChannels)

    var %ignore
    var %ignoreIndex = 1
    var %ignoreLines = $did(siteinviteDialog,110).lines

    while (%ignoreIndex <= %ignoreLines) {
      if ($did(siteinviteDialog,110,%ignoreIndex).cstate == 0) {

        var %ignoreText = $siteinvite_clean_channel($did(siteinviteDialog,110,%ignoreIndex).text)

        if (%ignoreText) {
          %ignore = $addtok(%ignore,%ignoreText,44)
        }
      }

      inc %ignoreIndex

    }

    set %buf.Site.Ignore $siteinvite_normalize_channel_csv(%ignore)

    ; Build ftpsites
    var %lines = $did(siteinviteDialog,120).lines

    if (%lines) {

      var %jc = 1
      var %ftps

      while (%jc <= %lines) {

        var %txt = $did(siteinviteDialog,120,%jc).text
        %ftps = $addtok(%ftps,%txt,44)
        inc %jc

      }

      set %buf.Site.FTPSites $sortcsv(%ftps)

    } else {
      unset %buf.Site.FTPSites
    }

    ; Build ftpsites_ignore from unchecked rows (inactive FTP-sites).
    var %ftpIgnore
    var %ftpIgnoreIndex = 1
    var %ftpIgnoreLines = $did(siteinviteDialog,120).lines

    while (%ftpIgnoreIndex <= %ftpIgnoreLines) {
      if ($did(siteinviteDialog,120,%ftpIgnoreIndex).cstate == 0) {

        var %ftpIgnoreText = $did(siteinviteDialog,120,%ftpIgnoreIndex).text
        %ftpIgnore = $addtok(%ftpIgnore,%ftpIgnoreText,44)

      }

      inc %ftpIgnoreIndex

    }

    if (%ftpIgnore) {
      set %buf.Site.FTPSitesIgnore $sortcsv(%ftpIgnore)
    } else {
      unset %buf.Site.FTPSitesIgnore
    }

    siteinvite_save

  }

  ; -------------------------------------------------------------
  ; Save ignore_entire for all sites based on check-state in list
  ; -------------------------------------------------------------

  save_ignore_entire

  ; -------------------------------------------------------------
  ; Find out which sites are in the listbox (this is the truth, not the in file)
  ; -------------------------------------------------------------

  var %listedSites
  var %lineCount = $did(siteinviteDialog,100).lines
  var %i = 1

  while (%i <= %lineCount) {

    %listedSites = $addtok(%listedSites,$did(siteinviteDialog,100,%i).text,44)
    inc %i

  }

  ; -------------------------------------------------------------
  ; Find out which sites exist in ini today
  ; -------------------------------------------------------------

  var %iniSites
  var %idx = 1

  while ($ini(%ini,%idx)) {

    var %sect = $v1

    if (%sect != Settings) {
      %iniSites = $addtok(%iniSites,%sect,44)
    }

    inc %idx

  }

  ; -------------------------------------------------------------
  ; Delete sites from ini that no longer exist in the listbox
  ; -------------------------------------------------------------

  var %x = 1
  var %cnt = $numtok(%iniSites,44)

  while (%x <= %cnt) {

    var %sect = $gettok(%iniSites,%x,44)

    if (!$istok(%listedSites,%sect,44)) {
      remini %ini %sect
    }

    inc %x

  }

  ; -------------------------------------------------------------
  ; Save all other sites, read directly from ini if they already existed there (only the difference in listbox affects what is saved)
  ; -------------------------------------------------------------

  var %z = 1

  while (%z <= %lineCount) {

    var %site = $did(siteinviteDialog,100,%z).text

    ; Skip the current site (already saved)
    if (%site == %currentSiteName) {

      inc %z
      continue

    }

    ; If the site doesn't exist in ini, create empty base
    if (!$readini(%ini,%site,name)) {
      safeWriteIni %ini %site name %site
    }

    inc %z

  }

  if ($isfile(%ini)) {
    flushini $qt(%ini)
  }

  unset %iniFileMTime

}

; ------------------------------------------------------------------------------
; Menu
; ------------------------------------------------------------------------------

menu * {

  SiteInvite Manager
  .Open:/siteinvite
  .Reload:load -rs $qt($scriptdir $+ SiteInvite.mrc)

}