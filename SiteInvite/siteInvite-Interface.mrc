;######################################
; AdIRC: SiteInvite-Interface         #
; Revision: 5                         #
; Date created: 05/09/2026            #
; Date last modified: 31/08/2026      #
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
; Global variables
; ------------------------------------------------------------------------------

var %siteInviteIniPath
var %currentSiteName
var %isCurrentlyLoading

; Buffer variables
var %buf.Settings.Debug
var %buf.Settings.Info
var %buf.Settings.Code
var %buf.Settings.Error
var %buf.Settings.BotNick
var %buf.Settings.CheckInterval
var %buf.Settings.SyncMode
var %buf.Settings.FlashFXP

; Buffer for site data
var %buf.Site.Name
var %buf.Site.BotNick
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
  size -1 -1 720 420
  option dbu

  box "Settings",900,10 10 700 80
  check "  Debug",1,25 30 40 10
  check "  Info",2,70 30 35 10
  check "  Code",3,105 30 40 10
  check "  Error",4,145 30 40 10

  text "Botnick:",10,190 30 35 10
  edit "",11,225 30 60 9,autohs

  text "Check interval (min):",18,290 30 60 9
  edit "",19,355 30 60 9,autohs

  text "Synchronize mode:",12,550 30 55 9
  radio " None",13,610 30 25 9
  radio " All",14,645 30 25 9

  text "FlashFXP Path:",15,25 55 75 9
  edit "",16,110 53 510 11,autohs
  button "...",17,630 53 40 11

  text "Config file:",30,25 75 75 9
  edit "",31,110 73 510 11,autohs
  button "...",32,630 73 40 11

  box "Sites",50,10 100 700 310
  list 100,25 120 180 260,vsbar sort check
  button "Add",200,25 375 45 12
  button "Edit",201,75 375 45 12
  button "Delete",202,125 375 50 12
  button "Close",203,630 375 60 14,cancel

  text "Name:",101,220 145 40 9
  edit "",102,260 143 200 11

  text "Botnick:",103,480 145 45 9
  edit "",104,530 143 130 11

  text "Network:",105,220 165 50 9
  edit "",106,275 163 180 11

  text "Channels:",107,220 195 60 9
  list 110,220 210 220 150,vsbar sort check
  button "Add",113,220 375 45 12
  button "Edit",114,270 375 45 12
  button "Delete",115,320 375 50 12

  text "FTP-Sites:",117,460 195 60 9
  list 120,460 210 220 150,vsbar sort check
  button "Add",123,460 375 45 12
  button "Edit",124,510 375 45 12
  button "Delete",125,560 375 50 12

}

; ------------------------------------------------------------------------------
; Dialog init
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:init:*:{

  set %isCurrentlyLoading 1
  unset %currentSiteName
  unset %buf.Site.*

  did -r siteinviteDialog 102,104,106,110,120

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

  if ($readini(%ini,Settings,BotNick) == $null) {
    safeWriteIni %ini Settings BotNick
  }

  if ($readini(%ini,Settings,CheckInterval) == $null) {
    safeWriteIni %ini Settings CheckInterval 60
  }

  if ($readini(%ini,Settings,SyncMode) == $null) {
    safeWriteIni %ini Settings SyncMode 0
  }

  if ($readini(%ini,Settings,FlashFXPPath) == $null) {
    safeWriteIni %ini Settings FlashFXPPath
  }

  var %displayIniFilePath = $remove(%iniFilePath,$chr(34))
  safeWriteIni %ini Settings ConfigFile %displayIniFilePath

  ; Read into buffer
  set %buf.Settings.Debug $readini(%iniFilePath,Settings,Debug)
  set %buf.Settings.Info $readini(%iniFilePath,Settings,Info)
  set %buf.Settings.Code $readini(%iniFilePath,Settings,Code)
  set %buf.Settings.Error $readini(%iniFilePath,Settings,Error)
  set %buf.Settings.BotNick $readini(%iniFilePath,Settings,BotNick)
  set %buf.Settings.CheckInterval $readini(%iniFilePath,Settings,CheckInterval)
  set %buf.Settings.SyncMode $readini(%iniFilePath,Settings,SyncMode)
  set %buf.Settings.FlashFXP $readini(%iniFilePath,Settings,FlashFXPPath)

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

  did -ra siteinviteDialog 11 %buf.Settings.BotNick
  did -ra siteinviteDialog 16 %buf.Settings.FlashFXP
  did -ra siteinviteDialog 31 %displayIniFilePath
  did -c siteinviteDialog $iif(%buf.Settings.SyncMode == 1,14,13)

  ; Populate sites
  did -r siteinviteDialog 100

  var %i = 1

  while ($ini(%iniFilePath,%i)) {

    var %site = $v1

    if (%site != Settings) {

      did -a siteinviteDialog 100 %site

      var %ignore = $readini(%iniFilePath,%site,ignore_entire)
      var %lineNum = $didwm(siteinviteDialog,100,%site)

      if (%ignore != 1) {
        did -s siteinviteDialog 100 %lineNum
      } else {
        did -c siteinviteDialog 100 %lineNum
      }
    }

    inc %i

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
  set %buf.Site.BotNick  $readini(%ini,$1,botnick)
  set %buf.Site.Network  $readini(%ini,$1,network)

  var %channels = $readini(%ini,%currentSiteName,channels)
  var %ignore   = $readini(%ini,%currentSiteName,ignore)
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

  ; Updates chan/ignore lists and checkbox/edit fields
  did -ra siteinviteDialog 102 %buf.Site.Name
  did -ra siteinviteDialog 104 %buf.Site.BotNick
  did -ra siteinviteDialog 106 %buf.Site.Network

  ; Channels

  did -r siteinviteDialog 110

  if (%buf.Site.Channels) {

    var %c = $numtok(%buf.Site.Channels,44)
    var %i = 1

    while (%i <= %c) {

      did -a siteinviteDialog 110 # $+ $gettok(%buf.Site.Channels,%i,44)

      inc %i

    }

    ; Check ignored
    if (%buf.Site.Ignore) {

      var %igncount = $numtok(%buf.Site.Ignore,44)
      var %y = 1

      while (%y <= %igncount) {

        var %ign = $gettok(%buf.Site.Ignore,%y,44)
        var %line = $didwm(siteinviteDialog,110,# $+ %ign)

        if (%line) {
          did -s siteinviteDialog 110 %line
        }

        inc %y

      }
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

    ; Check ignored
    if (%buf.Site.FTPSitesIgnore) {

      var %igncount = $numtok(%buf.Site.FTPSitesIgnore,44)
      var %y = 1

      while (%y <= %igncount) {

        var %ign = $gettok(%buf.Site.FTPSitesIgnore,%y,44)
        var %line = $didwm(siteinviteDialog,120,%ign)

        if (%line) {
          did -s siteinviteDialog 120 %line
        }

        inc %y

      }
    }
  }
}

on *:DIALOG:siteinviteDialog:edit:11:{

  if (%isCurrentlyLoading) {
    return
  }

  set %buf.Settings.BotNick $did(11).text

  save_settings

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
  isCheckBotTimer

}

on *:DIALOG:siteinviteDialog:sclick:13,14:{

  if (%isCurrentlyLoading) {
    return
  }

  set %buf.Settings.SyncMode $did(14).state

  save_settings

}

; ------------------------------------------------------------------------------
; Save checkboxes in settings - debug / info / code / error
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:1,2,3,4:{

  if (%isCurrentlyLoading) {
    return
  }

  if ($did == 1) {
    set %buf.Settings.Debug $did($did).state
  }

  if ($did == 2) {
    set %buf.Settings.Info $did($did).state
  }

  if ($did == 3) {
    set %buf.Settings.Code $did($did).state
  }

  if ($did == 4) {
    set %buf.Settings.Error $did($did).state
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
  safeWriteIni %ini Settings BotNick %buf.Settings.BotNick
  safeWriteIni %ini Settings FlashFXPPath %buf.Settings.FlashFXP
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
  safeWriteIni %ini %currentSiteName botnick  %buf.Site.BotNick
  safeWriteIni %ini %currentSiteName network  %buf.Site.Network

  ; ============================================================
  ; Channels
  ; ============================================================

  var %channels
  var %ignore
  var %i = 1
  var %lines = $did(siteinviteDialog,110).lines

  while (%i <= %lines) {

    var %channel = $did(siteinviteDialog,110,%i).text

    %channels = $addtok(%channels,%channel,44)

    if ($did(siteinviteDialog,110,%i).cstate == 1) {
      %ignore = $addtok(%ignore,%channel,44)
    }

    inc %i

  }

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

    if ($did(siteinviteDialog,120,%i).cstate == 1) {
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
; Click: select site (save current buffer first, load new site)
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:100:{

  save_ignore_entire

  var %selectedSiteName = $did(siteinviteDialog,100).seltext

  if (!%selectedSiteName) {
    return
  }

  ; Clicking the active site's checkbox must only update ignore_entire.
  if (%selectedSiteName == %currentSiteName) {
    return
  }

  ; Save current site in buffer first
  if (%currentSiteName) {

    set %buf.Site.Name $did(siteinviteDialog,102).text
    set %buf.Site.BotNick $did(siteinviteDialog,104).text
    set %buf.Site.Network $did(siteinviteDialog,106).text

    ; Channel save rows

    var %lines = $did(siteinviteDialog,110).lines

    if (%lines) {

      var %jc = 1
      var %chans

      while (%jc <= %lines) {

        var %txt = $did(siteinviteDialog,110,%jc).text
        var %clean = $remove(%txt,#)

        %chans = $addtok(%chans,%clean,44)

        inc %jc

      }

      set %buf.Site.Channels $sortcsv(%chans)

    } else {

      unset %buf.Site.Channels

    }

    ; Build ignore from checked
    var %cselnum = $did(siteinviteDialog,110).csel

    if (%cselnum > 0) {

      var %ign
      var %k = 1

      while (%k <= %cselnum) {

        var %ln = $did(siteinviteDialog,110).csel(%k)
        var %txt = $did(siteinviteDialog,110,%ln).text
        var %clean = $remove(%txt,#)

        %ign = $addtok(%ign,%clean,44)

        inc %k

      }

      set %buf.Site.Ignore $sortcsv(%ign)

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

    ; Build ftpsitesignore
    var %cselnum = $did(siteinviteDialog,120).csel

    if (%cselnum > 0) {

      var %ign
      var %k = 1

      while (%k <= %cselnum) {

        var %ln = $did(siteinviteDialog,120).csel(%k)
        var %txt = $did(siteinviteDialog,120,%ln).text

        %ign = $addtok(%ign,%txt,44)

        inc %k

      }

      set %buf.Site.FTPSitesIgnore $sortcsv(%ign)

    } else {

      unset %buf.Site.FTPSitesIgnore

    }

    siteinvite_save

  }

  ; Load selected site from on ini
  siteinvite_load %selectedSiteName

}

; ------------------------------------------------------------------------------
; Persist channel and FTP-site checkboxes independently of site selection.
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:110,120:{

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  siteinvite_save

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

  ; Add to listbox (locally), mark it and create empty buffer for it
  did -a siteinviteDialog 100 %newSiteName
  did -c siteinviteDialog 100 $did(siteinviteDialog,100).lines

  ; Save current site to buffer before we switch (if one was selected)
  if (%currentSiteName) {

    ; Same logic as in select-handler
    set %buf.Site.Name $did(siteinviteDialog,102).text
    set %buf.Site.BotNick $did(siteinviteDialog,104).text
    set %buf.Site.Network $did(siteinviteDialog,106).text

    ; Channel save rows

    var %lines = $did(siteinviteDialog,110).lines

    if (%lines) {

      var %jc = 1
      var %chans

      while (%jc <= %lines) {

        var %txt = $did(siteinviteDialog,110,%jc).text
        var %clean = $remove(%txt,#)

        %chans = $addtok(%chans,%clean,44)

        inc %jc

      }

      set %buf.Site.Channels $sortcsv(%chans)

    } else {

      unset %buf.Site.Channels

    }

    ; Build ignore from checked
    var %cselnum = $did(siteinviteDialog,110).csel

    if (%cselnum > 0) {

      var %ign
      var %k = 1

      while (%k <= %cselnum) {

        var %ln = $did(siteinviteDialog,110).csel(%k)
        var %txt = $did(siteinviteDialog,110,%ln).text
        var %clean = $remove(%txt,#)

        %ign = $addtok(%ign,%clean,44)

        inc %k

      }

      set %buf.Site.Ignore $sortcsv(%ign)

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

    ; Build ftpsitesignore
    var %cselnum = $did(siteinviteDialog,120).csel

    if (%cselnum > 0) {

      var %ign
      var %k = 1

      while (%k <= %cselnum) {

        var %ln = $did(siteinviteDialog,120).csel(%k)
        var %txt = $did(siteinviteDialog,120,%ln).text

        %ign = $addtok(%ign,%txt,44)

        inc %k

      }

      set %buf.Site.FTPSitesIgnore $sortcsv(%ign)

    } else {

      unset %buf.Site.FTPSitesIgnore

    }

    siteinvite_save

  }

  ; Set buffer for new site (empty)
  set %currentSiteName %newSiteName
  set %buf.Site.Name %newSiteName

  unset %buf.Site.BotNick
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

    ; Build ignore from checked
    var %cselnum = $did(siteinviteDialog,110).csel

    if (%cselnum > 0) {

      var %ign
      var %k = 1

      while (%k <= %cselnum) {

        var %ln = $did(siteinviteDialog,110).csel(%k)
        var %txt = $did(siteinviteDialog,110,%ln).text
        var %clean = $remove(%txt,#)

        %ign = $addtok(%ign,%clean,44)

        inc %k

      }

      set %buf.Site.Ignore $sortcsv(%ign)

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

    ; Build ftpsitesignore
    var %cselnum = $did(siteinviteDialog,120).csel

    if (%cselnum > 0) {

      var %ign
      var %k = 1

      while (%k <= %cselnum) {

        var %ln = $did(siteinviteDialog,120).csel(%k)
        var %txt = $did(siteinviteDialog,120,%ln).text

        %ign = $addtok(%ign,%txt,44)

        inc %k

      }

      set %buf.Site.FTPSitesIgnore $sortcsv(%ign)

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
    did -c siteinviteDialog 100 %selindex
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
    did -r siteinviteDialog 102,104,106,110,120

    ; Remove from INI immediately
    var %ini = %siteInviteIniPath

    remini %ini %selectedSiteName

  }

  if (!$did(siteinviteDialog,100).lines) || (!$did(siteinviteDialog,100).sel) {

    unset %currentSiteName
    unset %buf.Site.*

    did -r siteinviteDialog 102,104,106,110,120

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

  if ($istok(%normalizedChannelList,$remove(%channelName,#),44)) {

    noop $input(Channel: %channelName already exists! $crlf $crlf $crlf,i)

    return

  }

  var %newRawChannelList

  if (%rawChannelString) {
    %newRawChannelList = %rawChannelString $+ , $+ $remove(%channelName,#)
  } else {
    %newRawChannelList = $remove(%channelName,#)
  }

  var %sortedNormalizedChannels = $sortcsv(%newRawChannelList)

  set %buf.Site.Channels %sortedNormalizedChannels

  ; Update ui from buffer
  siteinvite_refresh_ui

  ; Select the new channel in list
  var %lineCount = $did(siteinviteDialog,110).lines
  var %lineIndex = 1

  while (%lineIndex <= %lineCount) {

    if ($did(siteinviteDialog,110,%lineIndex).text == # $+ $remove(%channelName,#)) {

      did -c siteinviteDialog 110 %lineIndex

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
  var %oldChannel = $remove(%oldChannelWithHash,#)
  var %newChannel = $remove(%newChannelWithHash,#)

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

  set %buf.Site.Channels $sortcsv(%newList)

  ; Update ignore buffer if previously checked
  if (%wasChecked) {

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

  var %cleaned = $remove(%selectedLine,#)

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

  set %buf.Site.Channels $sortcsv(%newList)

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

  ; Update ui from buffer
  siteinvite_refresh_ui

  ; Select the new ftp-site in list
  var %lineCount = $did(siteinviteDialog,120).lines
  var %lineIndex = 1

  while (%lineIndex <= %lineCount) {

    if ($did(siteinviteDialog,120,%lineIndex).text == %ftpName) {

      did -c siteinviteDialog 120 %lineIndex

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

  ; If was checked, update ignore buffer too
  if (%wasChecked == 1) {

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

  if (!%currentSiteName || %isCurrentlyLoading) {
    return
  }

  var %id = $did
  var %text = $did($dname,$did).text

  if (%id == 102) {
    set %buf.Site.Name %text
  } elseif (%id == 104) {
    set %buf.Site.BotNick %text
  } elseif (%id == 106) {
    set %buf.Site.Network %text
  }

  siteinvite_save

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
; Select the SiteInvite configuration file
; ------------------------------------------------------------------------------

on *:DIALOG:siteinviteDialog:sclick:32:{

  var %newIniFilePath = $sfile(Select configuration file,*.dat)

  if (%newIniFilePath) {
    siteinvite_activate_config %newIniFilePath
  }

}

on *:DIALOG:siteinviteDialog:edit:31:{

  if (%isCurrentlyLoading) {
    return
  }

  var %newIniFilePath = $did(siteinviteDialog,31).text

  if ($lower($right(%newIniFilePath,4)) != .dat) {
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
    set %buf.Site.BotNick $did(siteinviteDialog,104).text
    set %buf.Site.Network $did(siteinviteDialog,106).text

    ; Build channels
    var %lines = $did(siteinviteDialog,110).lines

    if (%lines) {

      var %jc = 1
      var %chans

      while (%jc <= %lines) {

        var %txt = $did(siteinviteDialog,110,%jc).text
        var %clean = $remove(%txt,#)

        %chans = $addtok(%chans,%clean,44)

        inc %jc

      }

      set %buf.Site.Channels $sortcsv(%chans)

    } else {

      unset %buf.Site.Channels

    }

    ; Build ignore
    var %lines = $did(siteinviteDialog,110).lines
    var %ign
    var %i = 1

    while (%i <= %lines) {

      if ($did(siteinviteDialog,110,%i).cstate == 1) {

        var %txt = $did(siteinviteDialog,110,%i).text
        var %clean = $remove(%txt,#)

        %ign = $addtok(%ign,%clean,44)

      }

      inc %i

    }

    if (%ign) {
      set %buf.Site.Ignore $sortcsv(%ign)
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

    ; Build ftpsitesignore
    var %lines = $did(siteinviteDialog,120).lines
    var %ign
    var %i = 1

    while (%i <= %lines) {

      if ($did(siteinviteDialog,120,%i).cstate == 1) {

        var %txt = $did(siteinviteDialog,120,%i).text

        %ign = $addtok(%ign,%txt,44)

      }

      inc %i

    }

    if (%ign) {

      set %buf.Site.FTPSitesIgnore $sortcsv(%ign)

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
}

; ------------------------------------------------------------------------------
; Menu
; ------------------------------------------------------------------------------

menu * {
  SiteInvite Manager
  .Open:/siteinvite
  .Reload:load -rs $qt($scriptdir $+ SiteInvite.mrc)
}