;######################################
; AdIRC: SiteInvite-Code              #
; Revision: 3                         #
; Date created: 05/09/2026            #
; Date last modified: 25/09/2026      #
; Author: Whiskey                     #
; #####################################

; ----------------------------------------
; START
; ----------------------------------------

on *:START:{

  ; ----------------------------------------
  ; Set default variables
  ; ----------------------------------------

  ; Use the selected configuration file, or the default .dat file.
  set %siteInviteConfigPath $siteinvite_config_path
  set %iniFilePath %siteInviteConfigPath

  ; Unset saved time.
  unset %iniFileMTime
  unset %lastCheckInterval

  ; ----------------------------------------
  ; Get values from data file.
  ; ----------------------------------------

  GetData

  ; ----------------------------------------
  ; Start check timer.
  ; ----------------------------------------

  isCheckTimer

}


; ----------------------------------------
; Alias: siteinvite_config_path
; Description: Returns the active configuration file.
; ----------------------------------------

alias siteinvite_config_path {

  if (%siteInviteConfigPath) {
    return %siteInviteConfigPath
  }

  return $qt($scriptdir $+ siteInvite-Sites.dat)

}


; =========================================================
; NOTE:
;
; There is intentionally NO RAW 473 handler.
;
; A 473 response means that an attempted JOIN was rejected
; because the channel is invite-only.
;
; This script must NEVER react to 473 by trying to invite
; the current user.
;
; The periodic isCheck routine is responsible for User
; and Bot invite handling.
; =========================================================


; ----------------------------------------
; Alias: einvite
; Description: Returns the custom @Invite window name.
; ----------------------------------------

alias -l einvite {

  ; Set variables.
  var %msg = $1-
  var %reset = $chr(15)
  var %color

  ; Must start with [.
  if ($left(%msg,1) == [) {

    var %end = $pos(%msg,],1)

    if (%end) {

      var %inside = $mid(%msg,2,$calc(%end - 2))

      ; Set color based on type.
      if (*Info* iswm %inside) {
        %color = $chr(3) $+ 3
      }
      elseif (*Debug* iswm %inside) {
        %color = $chr(3) $+ 7
      }
      elseif (*Error* iswm %inside) {
        %color = $chr(3) $+ 4
      }
      elseif (*Code* iswm %inside) {
        %color = $chr(3) $+ 0
      }
    }
  }

  ; Check what message to send.
  if (%color) {
    isSynchronize $network %color $+ %msg $+ %reset
  }
  else {
    isSynchronize $network %msg
  }

}


; =========================================================
; GetData
; Description: Loads the ini file into hash tables.
; Uses caching and reloads only if the file changed.
; =========================================================

alias GetData {

  ; -------------------------------------------------------
  ; Safety check: ini file must exist.
  ; -------------------------------------------------------

  if (!$isfile(%iniFilePath)) {
    return
  }

  ; -------------------------------------------------------
  ; Cache validation: reload only if file changed.
  ; -------------------------------------------------------

  var %current_mtime = $file(%iniFilePath).mtime

  if ((%current_mtime == %iniFileMTime) && ($hget(settings)) && ($hget(sites))) {
    return
  }

  set %iniFileMTime %current_mtime

  ; -------------------------------------------------------
  ; Reset hash tables.
  ; -------------------------------------------------------

  if ($hget(settings)) {
    hfree settings
  }

  if ($hget(sites)) {
    hfree sites
  }

  hmake settings 100
  hmake sites 1000

  ; =======================================================
  ; Load settings section.
  ; =======================================================

  var %setting_index = 1
  var %setting_count = $ini(%iniFilePath, Settings, 0)

  while (%setting_index <= %setting_count) {

    var %setting_key = $ini(%iniFilePath, Settings, %setting_index)
    var %setting_value = $readini(%iniFilePath, Settings, %setting_key)

    hadd settings %setting_key %setting_value

    inc %setting_index

  }

  ; =======================================================
  ; Load all site sections.
  ; =======================================================

  var %section_index = 1
  var %section_count = $ini(%iniFilePath, 0)

  while (%section_index <= %section_count) {

    var %section_name = $ini(%iniFilePath, %section_index)

    ; Skip settings section.
    if (%section_name != Settings) {

      var %site_key_index = 1
      var %site_key_count = $ini(%iniFilePath, %section_name, 0)

      while (%site_key_index <= %site_key_count) {

        var %site_key = $ini(%iniFilePath, %section_name, %site_key_index)
        var %site_value = $readini(%iniFilePath, %section_name, %site_key)

        ; Stored as: SiteName.Key.
        hadd sites %section_name $+ . $+ %site_key %site_value

        inc %site_key_index

      }
    }

    inc %section_index

  }

}


; ----------------------------------------
; Alias: GetSetting
; Description: Returns a value from [Settings].
; ----------------------------------------

alias GetSetting {

  GetData

  return $hget(settings, $1)

}


; ----------------------------------------
; Alias: GetSite
; Description: Returns a site-specific value.
; ----------------------------------------

alias GetSite {

  GetData

  return $hget(sites, $1 $+ . $+ $2)

}


; ----------------------------------------
; Alias: getAllSites
; Description: Returns all configured site names.
; ----------------------------------------

alias getAllSites {

  var %sites
  var %index = 1

  while ($hfind(sites, *.name, %index, w)) {

    %sites = %sites $gettok($v1, 1, 46)

    inc %index

  }

  return %sites

}


; ----------------------------------------
; Alias: isCheckTimer
; Description: Handles the timer for isCheck.
; ----------------------------------------

alias isCheckTimer {

  var %intervalMin = $GetSetting(CheckInterval)

  ; Fallback.
  if (!%intervalMin) {
    %intervalMin = 60
  }

  ; Make sure the interval is at least one minute.
  if (%intervalMin < 1) {
    %intervalMin = 1
  }

  ; Recreate timer if the interval changed
  ; or if the timer does not exist.
  if (%intervalMin != %lastCheckInterval || !$timer(siteInviteCheck)) {

    set %lastCheckInterval %intervalMin

    ; Stop old timers.
    .timerCheckBot off
    .timerSiteInviteCheck off

    ; Convert minutes to seconds.
    var %intervalSec = $calc(%intervalMin * 60)

    ; Safety net.
    if (%intervalSec < 60) {
      %intervalSec = 60
    }

    ; Start timer.
    timerSiteInviteCheck 0 %intervalSec isCheck

    ; Run the first check immediately.
    isCheck

  }

}


; ----------------------------------------
; Backward compatibility aliases.
; ----------------------------------------

alias isCheckBotTimer {
  isCheckTimer
}


alias isTimerBot {
  isCheckTimer
}


; =========================================================
; isCheck
;
; Automatic User and Bot check.
;
; For every configured site/channel:
;
;   1. Is the configured network the current network?
;   2. Is Whiskey already in the channel?
;
;      NO:
;        - Show that Whiskey is missing.
;        - Run the normal User invite through isInvite.
;        - isInvite then uses isFTP.
;
;      YES:
;        - Is the BotNick already in the channel?
;
;          YES:
;            - Everything is working.
;            - Stay completely silent.
;
;          NO:
;            - Check Whiskey's channel status.
;            - Channel status -> direct IRC INVITE.
;            - Normal user -> FlashFXP fallback.
;
; There is deliberately NO JOIN here.
; =========================================================

alias isCheck {

  var %debug = $GetSetting(Debug)
  var %info = $GetSetting(Info)
  var %error = $GetSetting(Error)
  var %code = $GetSetting(Code)
  var %globalBotNick = $GetSetting(BotNick)
  var %sites = $getAllSites

  if (!%sites) {

    if (%error) {
      einvite [isCheckError] No sites configured
    }

    return
  }

  var %i = 1
  var %siteCount = $numtok(%sites, 32)

  while (%i <= %siteCount) {

    var %site = $gettok(%sites, %i, 32)
    var %siteNetwork = $GetSite(%site, network)

    if (%siteNetwork && $lower(%siteNetwork) != $lower($network)) {

      if (%debug) {
        einvite [isCheckDebug] Skipping %site - network %siteNetwork does not match $network
      }

    }
    else {

      var %botnick = $GetSite(%site, botnick)

      if (!%botnick) {
        %botnick = %globalBotNick
      }

      var %channelList = $GetSite(%site, channels)

      if (!%channelList) {

        if (%debug) {
          einvite [isCheckDebug] No channels configured for site %site
        }

      }
      elseif (!%botnick) {

        if (%error) {
          einvite [isCheckError] No BotNick configured for site %site
        }

      }
      else {

        var %j = 1
        var %channelCount = $numtok(%channelList, 44)

        while (%j <= %channelCount) {

          var %channel = $gettok(%channelList, %j, 44)

          if ($left(%channel, 1) != #) {
            %channel = # $+ %channel
          }

          %channel = $lower(%channel)

          ; ----------------------------------------
          ; Whiskey is NOT in the channel.
          ; Always use the User/FlashFXP path.
          ; ----------------------------------------

          if (!$nick(%channel, $me)) {

            if (%info) {
              einvite [isCheckInfo] Whiskey is NOT in %channel
            }

            isInvite %channel User $me

          }
          else {

            ; ----------------------------------------
            ; Whiskey is present.
            ;
            ; If PR3 is also present, everything is
            ; working and this channel remains silent.
            ; ----------------------------------------

            if (!$nick(%channel, %botnick)) {

              if (%info) {
                einvite [isCheckInfo] Whiskey is in %channel
                einvite [isCheckInfo] %botnick is NOT in %channel
              }

              ; ----------------------------------------
              ; Check Whiskey's current channel status.
              ; ----------------------------------------

              var %pnick = $nick(%channel, $me).pnick
              var %prefix = $left(%pnick, 1)

              if (%debug) {
                einvite [isCheckDebug] Whiskey status in %channel $+ : %pnick
              }

              ; ----------------------------------------
              ; Channel operator/halfop/admin/owner:
              ; use direct IRC INVITE.
              ; ----------------------------------------

              if ($istok(~ & @ %, %prefix, 32)) {

                if (%info) {
                  einvite [isCheckInfo] Direct INVITE for %botnick to %channel
                }

                quote INVITE %botnick %channel

                if (%code) {
                  einvite [isCheckCode] Direct INVITE %botnick -> %channel
                }

              }
              else {

                ; ----------------------------------------
                ; Normal user:
                ; use FlashFXP as fallback.
                ; ----------------------------------------

                if (%debug) {
                  einvite [isCheckDebug] Whiskey is a normal user in %channel $+ : %pnick
                }

                if (%info) {
                  einvite [isCheckInfo] Falling back to FlashFXP for %botnick in %channel
                }

                isInvite %channel Bot %botnick

              }
            }
          }

          inc %j

        }
      }
    }

    inc %i

  }

}


; ----------------------------------------
; Backward compatibility.
; ----------------------------------------

alias isCheckBot {
  isCheck $1-
}


; =========================================================
; isSynchronize
; Description: Synchronize invite messages.
; =========================================================

alias isSynchronize {

  var %SyncMode = $GetSetting(SyncMode)
  var %origin_network = $1
  var %message = $2-

  ; Validate SyncMode.
  if (%SyncMode != 0 && %SyncMode != 1) {
    %SyncMode = 0
  }

  if (!%origin_network) {
    %origin_network = $network
  }

  ; Determine whether a window should be opened.
  var %should_open = 0

  if ($pos(%message, Unable to join #, 1) && $pos(%message, (invite only), 1)) {
    %should_open = 1
  }
  elseif (*Error* iswm %message || *attempting invite* iswm %message || *FlashFXP started* iswm %message || *Inviting* iswm %message || *Triggering FlashFXP* iswm %message) {
    %should_open = 1
  }

  var %i = 1

  while ($scon(%i)) {

    scon %i

    if ($network) {

      var %win = @Invite- $+ $network

      ; ----------------------------------------
      ; Origin network.
      ; ----------------------------------------

      if ($network == %origin_network) {

        if (!$window(%win) && %should_open) {
          window -en %win
        }

        if ($window(%win)) {

          if (%SyncMode == 1) {
            echo -tq %win $+([,%origin_network,]) %message
          }
          else {
            echo -tq %win %message
          }

        }

      }

      ; ----------------------------------------
      ; Other networks.
      ; ----------------------------------------

      elseif (%SyncMode == 1) {

        if ($window(%win)) {
          echo -tq %win $+([,%origin_network,]) %message
        }

      }
    }

    inc %i

  }

}


; =========================================================
; isInvite
; Description: Main handler for invite events.
; Usage: isInvite [channel] [target: User|Bot] [targetNick]
; =========================================================

alias isInvite {

  var %debug = $GetSetting(Debug)
  var %error = $GetSetting(Error)
  var %info = $GetSetting(Info)

  ; ----------------------------------------
  ; Parse target.
  ; ----------------------------------------

  var %target = $2

  if (!%target) {
    %target = User
  }

  %target = $upper(%target)

  var %targetNick = $3

  ; User means current IRC nick.
  if (%target == USER) {

    %target = User

    if (!%targetNick) {
      %targetNick = $me
    }

  }
  ; Bot means configured BotNick.
  elseif (%target == BOT) {

    %target = Bot

    if (!%targetNick) {

      %targetNick = $GetSite($1, botnick)

      if (!%targetNick) {
        %targetNick = $GetSetting(BotNick)
      }

    }

  }
  else {

    if (%error) {
      einvite [isInviteError] Unknown target: %target
    }

    return
  }

  ; ----------------------------------------
  ; Parse channel.
  ; ----------------------------------------

  if ($1) {
    var %channel = $1
  }
  else {
    var %channel = $strip($gettok($rawmsg, 4, 32))
  }

  if (!%channel) {

    if (%error) {
      einvite [isInviteError-%target] Unable to determine channel
    }

    return
  }

  ; Add # if necessary.
  if ($left(%channel, 1) != #) {
    %channel = # $+ %channel
  }

  %channel = $lower(%channel)

  if (!%targetNick) {

    if (%error) {
      einvite [isInviteError-%target] Missing target nick for %target in %channel
    }

    return
  }

  ; ----------------------------------------
  ; IMPORTANT:
  ; For Bot invites, $me MUST be in the channel.
  ; ----------------------------------------

  if (%target == Bot) {

    if (!$nick(%channel, $me)) {

      if (%debug) {
        einvite [isInviteDebug-Bot] $me is not in %channel - refusing Bot invite
      }

      return
    }

  }

  ; ----------------------------------------
  ; Target already present?
  ; ----------------------------------------

  if ($nick(%channel, %targetNick)) {

    if (%info) {
      einvite [isInviteInfo-%target] %targetNick is already in %channel - skipping invite
    }

    if (%debug) {
      einvite [isInviteDebug-%target] Target already present: %targetNick in %channel
    }

    return
  }

  ; ----------------------------------------
  ; Resolve site.
  ; ----------------------------------------

  var %siteResult = $isSite(%channel)
  var %result = $gettok(%siteResult, 1, 32)

  if (%result == 0) {

    if (%error) {
      einvite [isInviteError-%target] No site found for %channel
    }

    return
  }

  var %site = $gettok(%siteResult, 2, 32)
  var %name = $gettok(%siteResult, 3, 32)

  if (%debug) {
    einvite [isInviteDebug-%target] Site resolved: %site ( %name ) for channel %channel
  }

  ; ----------------------------------------
  ; Check cooldown.
  ; ----------------------------------------

  if ($isTimer(%site, %target)) {

    if (%debug) {
      einvite [isInviteDebug-%target] Invite timer active for %site - skipping invite
    }

    return
  }

  ; ----------------------------------------
  ; Final safety check.
  ; ----------------------------------------

  if (%target == Bot && !$nick(%channel, $me)) {

    if (%debug) {
      einvite [isInviteDebug-Bot] $me left %channel before invite - stopping
    }

    return
  }

  if ($nick(%channel, %targetNick)) {

    if (%info) {
      einvite [isInviteInfo-%target] %targetNick joined %channel before invite - skipping invite
    }

    return
  }

  if (%debug) {
    einvite [isInviteDebug-%target] Starting FTP invite: site=%site channel=%channel target=%target targetNick=%targetNick
  }

  isFTP %site %channel %target %targetNick

}


; =========================================================
; isSite
; Description: Check if channel belongs to known site.
; Returns: 1 <site> <name> or 0.
; =========================================================

alias isSite {

  var %channel = $1
  var %debug = $GetSetting(Debug)

  ; Get all sites.
  var %sitesList = $getAllSites
  var %siteCount = $numtok(%sitesList, 32)
  var %i = 1

  while (%i <= %siteCount) {

    var %site = $gettok(%sitesList, %i, 32)
    var %channels = $GetSite(%site, channels)
    var %name = $GetSite(%site, name)
    var %ignore_entire = $GetSite(%site, ignore_entire)
    var %siteNetwork = $GetSite(%site, network)

    ; Skip site if its network does not match.
    if (!%siteNetwork || $lower(%siteNetwork) == $lower($network)) {

      ; Normalize configured channels.
      var %normChannels
      var %chIdx = 1
      var %chCnt = $numtok(%channels, 44)

      while (%chIdx <= %chCnt) {

        var %cTok = $gettok(%channels, %chIdx, 44)

        if ($left(%cTok, 1) != #) {
          %cTok = # $+ %cTok
        }

        %normChannels = $addtok(%normChannels, $lower(%cTok), 44)

        inc %chIdx

      }

      ; Check if site contains this channel.
      if ($istok(%normChannels, $lower(%channel), 44)) {

        ; Check if entire site should be ignored.
        if (%ignore_entire == 1) {

          if (%debug) {
            einvite [isSiteDebug] Site %site is entirely ignored
          }

          return 0
        }

        if (%debug) {
          einvite [isSiteDebug] Site resolved: %site ( %name ) for channel %channel
        }

        return 1 %site %name

      }
    }

    inc %i

  }

  if (%debug) {
    einvite [isSiteDebug] Unknown channel: %channel
  }

  return 0

}


; =========================================================
; isTimer
; Description: Per-site cooldown system.
; Usage: $isTimer(site, target)
; =========================================================

alias isTimer {

  var %site = $1
  var %target = $2
  var %debug = $GetSetting(Debug)

  if (!%target) {
    %target = User
  }

  ; Initialize hash table.
  if (!$hget(inviteTimers)) {
    hmake inviteTimers 20
  }

  var %key = %site $+ . $+ %target
  var %lastTime = $hget(inviteTimers, %key)

  ; ----------------------------------------
  ; Only calculate elapsed time when a previous
  ; timestamp actually exists.
  ; ----------------------------------------

  if (%lastTime) {

    var %timePassed = $calc($ctime - %lastTime)

    if (%timePassed < 60) {

      if (%debug) {
        einvite $+([,isTimerDebug-,%target,]) %site timer is active: $calc(60 - %timePassed) seconds remaining
      }

      return 1
    }

  }

  ; Start/restart cooldown.
  hadd inviteTimers %key $ctime

  if (%debug) {
    einvite $+([,isTimerDebug-,%target,]) No active timer for %site
  }

  return 0

}

; ----------------------------------------
; Function: isFTP
; Description: Runs FlashFXP against relevant site
; Usage: isFTP <site> <channel> [target: User|Bot] [targetNick]
; ----------------------------------------

alias isFTP {

  ; Enable local error handling to catch the exact line and error
  :error
  if ($error) {
    echo -a --------------------------------------------------
    echo -a [isFTP-CRASH] Crash occurred on line: $scriptline
    echo -a [isFTP-CRASH] Error message: $error
    echo -a --------------------------------------------------
    reseterror
    return
  }

  ; Set local variables directly from parameters
  var %site = $1
  var %channel = $2
  var %argument3 = $3
  var %argument4 = $4
  var %alias = isFTP

  if (%argument3 == User || %argument3 == Bot) {
    var %target = %argument3
    var %targetNick = %argument4
  }
  else {
    var %targetNick = %argument3
    var %target = $iif(%targetNick == $me, User, Bot)
  }

  var %testMode = $iif(%argument4 == setting, 1, 0)

  if (!%site) {
    einvite $+([,%alias,Error-,%target,]) Missing site parameter in isFTP call
    return
  }

  var %debug = $GetSetting(Debug)
  var %info = $GetSetting(Info)
  var %code = $GetSetting(Code)
  var %error = $GetSetting(Error)

  if (%debug) {
    einvite $+([,%alias,Debug-,%target,]) Entering isFTP, site: %site, channel: %channel
  }

  var %flashfxp_path = $GetSetting(FlashFXPPath)

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) flashfxp_path: %flashfxp_path
  }

  if (%info) {
    einvite $+([,%alias,Info-,%target,]) Triggering FlashFXP for %site / %channel
  }

  ; Safety check: target nick presence
  if (!%testMode) {
    if (!%targetNick) {
      einvite $+([,%alias,Error-,%target,]) Missing target nick for %target in %channel - skipping invite
      return
    }

    if ($nick(%channel, %targetNick)) {
      if (%error) {
        einvite $+([,%alias,Error-,%target,]) %targetNick is already in %channel - skipping invite
      }
      if (%debug) {
        einvite $+([,%alias,Debug-,%target,]) Target %targetNick is already in %channel - isFTP stopped before FlashFXP
      }
      return
    }
  }
  elseif (%code) {
    einvite $+([,%alias,Code-,%target,]) Test mode enabled - ignoring target presence check
  }

  ; Synchronize FlashFXP Sites.dat
  var %siteInviteDataFile = $scriptdir $+ SiteInvite-Sites.dat
  var %flashPath = %buf.Settings.FlashAppData

  if (!%flashPath) { %flashPath = $GetSetting(FlashAppData) }
  if (!%flashPath) { %flashPath = $env(APPDATA) $+ \FlashFXP\5\ }

  %flashPath = $remove(%flashPath, $chr(34))
  if (%flashPath && $right(%flashPath, 1) != \) { %flashPath = %flashPath $+ \ }

  var %defaultDataFile = %flashPath $+ Sites.dat
  var %dataFile = $null

  if ($isfile(%defaultDataFile)) {
    %dataFile = %defaultDataFile
  }
  else {
    var %searchRoot = $env(APPDATA)
    if (%searchRoot && $isdir(%searchRoot)) {
      %dataFile = $findfile(%searchRoot, Sites.dat, 1, 10)
    }
  }

  if (%dataFile) {
    var %sourceMTime = $file(%dataFile).mtime
    var %localMTime = $iif($isfile(%siteInviteDataFile), $file(%siteInviteDataFile).mtime, 0)

    if (%code) {
      var %safeDataFile = $replace(%dataFile, $chr(44), $chr(32))
      einvite $+([,%alias,Code-,%target,]) FlashFXP database: %safeDataFile
      einvite $+([,%alias,Code-,%target,]) FlashFXP database timestamp: %sourceMTime
      einvite $+([,%alias,Code-,%target,]) Local database timestamp: %localMTime
    }

    if (!$isfile(%siteInviteDataFile) || %sourceMTime != %localMTime) {
      copy -o $qt(%dataFile) $qt(%siteInviteDataFile)
      if (!$isfile(%siteInviteDataFile)) {
        if (%error) {
          einvite $+([,%alias,Error-,%target,]) Could not copy FlashFXP database to: %siteInviteDataFile
        }
        return
      }
      if (%code) {
        einvite $+([,%alias,Code-,%target,]) Updated local FlashFXP database: %siteInviteDataFile
      }
    }
    elseif (%code) {
      einvite $+([,%alias,Code-,%target,]) Local FlashFXP database is up to date
    }
  }
  elseif (%error) {
    einvite $+([,%alias,Error-,%target,]) FlashFXP Sites.dat not found. Checked: %defaultDataFile
  }

  ; Get ftpsites and ignores from config
  var %ftpsites = $GetSite(%site, ftpsites)

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) Raw ftpsites input: %ftpsites
  }

  var %ftpsites_ignore = $GetSite(%site, ftpsites_ignore)

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) ftpsites_ignore: %ftpsites_ignore
  }

  ; Filter out ftpsites_ignore first
  if (%ftpsites_ignore != $null && %ftpsites != $null) {
    var %validList = $null
    var %totalSites = $numtok(%ftpsites, 44)
    var %i = 1

    while (%i <= %totalSites) {
      var %currSite = $gettok(%ftpsites, %i, 44)
      var %cleanCurr = $remove(%currSite, *)
      %cleanCurr = $regsubex(%cleanCurr, /^\s+|\s+$/g, $null)

      var %isIgnored = $false
      var %ignoreCount = $numtok(%ftpsites_ignore, 44)
      var %ig = 1

      while (%ig <= %ignoreCount) {
        var %ign = $gettok(%ftpsites_ignore, %ig, 44)
        var %cleanIgn = $remove(%ign, *)
        %cleanIgn = $regsubex(%cleanIgn, /^\s+|\s+$/g, $null)

        if (%cleanCurr == %cleanIgn) {
          %isIgnored = $true
          break
        }
        inc %ig
      }

      if (!%isIgnored) {
        %validList = $addtok(%validList, %currSite, 44)
      }
      elseif (%code) {
        einvite $+([,%alias,Code-,%target,]) Ignored site excluded: %currSite
      }

      inc %i
    }

    %ftpsites = %validList
  }

  ; --- SKANNA OCH KOLLA OFFLINE-SITES (BÅDE INI OCH DATABAS) ---
  var %totalFtpCount = $numtok(%ftpsites, 44)
  var %offlineList = $null
  var %offlineCount = 0
  var %onlineFtpSites = $null
  var %s = 1

  while (%s <= %totalFtpCount) {
    var %siteItem = $gettok(%ftpsites, %s, 44)
    var %cleanItem = $remove(%siteItem, *)
    %cleanItem = $regsubex(%cleanItem, /^\s+|\s+$/g, $null)

    var %isOffline = $false

    ; 1. Kolla om nyckeln/namnet i ftpsites-listan har [Offline]
    if (*[Offline]* iswm %siteItem || *[Offline]* iswm %cleanItem) {
      %isOffline = $true
    }

    ; 2. Kolla i SiteInvite-Sites.dat om profilen är offline
    if (!%isOffline && $isfile(%siteInviteDataFile)) {
      var %totLines = $lines(%siteInviteDataFile)
      var %l = 1

      while (%l <= %totLines) {
        var %line = $read(%siteInviteDataFile, %l)
        if (* $+ %cleanItem $+ * iswm %line) {
          if (*[Offline]* iswm %line) {
            %isOffline = $true
            break
          }
        }
        inc %l
      }
    }

    if (%isOffline) {
      %offlineList = $addtok(%offlineList, %cleanItem, 44)
      inc %offlineCount
    }
    else {
      %onlineFtpSites = $addtok(%onlineFtpSites, %siteItem, 44)
    }

    inc %s
  }

  ; Skriv ut offline-summeringen om %code är igång
  if (%code) {
    var %safeOfflineList = $iif(%offlineList != $null, $replace(%offlineList, $chr(44), $chr(32)), ingen)
    einvite $+([,%alias,Code-,%target,]) FTP sites offline: %safeOfflineList (,%offlineCount $+ / $+ %totalFtpCount $+ )
  }

  ; Använd endast online-sajterna för urvalet
  %ftpsites = %onlineFtpSites
  var %remainingCount = $numtok(%ftpsites, 44)

  if (!%remainingCount) {
    einvite $+([,%alias,Error-,%target,]) No valid ftpsites available for %site (all offline, ignored or none defined)
    return
  }

  ; Pick a random ftpsite key from active/online list
  var %randIndex = $rand(1, %remainingCount)
  var %picked = $gettok(%ftpsites, %randIndex, 44)

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) Picked site key: %picked
  }

  var %cleanKey = $remove(%picked, *)
  %cleanKey = $regsubex(%cleanKey, /^\s+|\s+$/g, $null)

  ; --- UPPSLAGNING AV PROFILNAMN ---
  var %iniFile = $GetSetting(ConfigFile)
  if (!%iniFile) { %iniFile = settings.ini }

  var %lookupSource = UNKNOWN
  var %realSiteName = $null

  ; Steg 1: Sök i sektionen [siteInvite-FlashFXP] i settings.ini
  if (%code) {
    einvite $+([,%alias,Code-,%target,]) Searching ini file: %iniFile [Section: siteInvite-FlashFXP] Key: %cleanKey
  }

  %realSiteName = $readini(%iniFile, n, siteInvite-FlashFXP, %cleanKey)
  if (%realSiteName) {
    %lookupSource = settings.ini [siteInvite-FlashFXP] (%iniFile)
  }
  else {
    %realSiteName = $readini(%iniFile, n, siteInvite-FlashFXP, %picked)
    if (%realSiteName) {
      %lookupSource = settings.ini [siteInvite-FlashFXP] (%iniFile via %picked)
    }
  }

  ; Steg 2: Sök i SiteInvite-Sites.dat
  if (!%realSiteName) {
    if ($isfile(%siteInviteDataFile)) {
      %lookupSource = FlashFXP Database (%siteInviteDataFile)

      var %totL = $lines(%siteInviteDataFile)
      var %lineNo = 1

      while (%lineNo <= %totL) {
        var %lineContent = $read(%siteInviteDataFile, %lineNo)

        if (* $+ %cleanKey $+ * iswm %lineContent && *[Offline]* !iswm %lineContent) {
          var %cleanLine = %lineContent
          if ($left(%cleanLine, 1) == [) { %cleanLine = $mid(%cleanLine, 2) }
          if ($right(%cleanLine, 1) == ]) { %cleanLine = $left(%cleanLine, -1) }

          var %cleanSec = $regsubex(%cleanLine, /[\x00-\x1F\x7F]/g, \)
          %cleanSec = $regsubex(%cleanSec, /\\+/g, \)

          var %extracted = $gettok(%cleanSec, -1, 92)
          %extracted = $regsubex(%extracted, /^\s+|\s+$/g, $null)

          if (%extracted) {
            %realSiteName = %extracted
            break
          }
        }
        inc %lineNo
      }
    }
  }

  ; Steg 3: Fallback
  if (!%realSiteName) {
    %realSiteName = %cleanKey
    %lookupSource = FALLBACK (Not found in siteInvite-FlashFXP or FlashFXP database)
  }

  var %safeLogName = $replace(%realSiteName, $chr(44), $chr(32))
  var %safeSource = $replace(%lookupSource, $chr(44), $chr(32))

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) Source for site profile: %safeSource
    einvite $+([,%alias,Code-,%target,]) Resolved full site profile: %safeLogName
  }

  ; SÖKVÄGBYGGANDE
  var %ftpSite = Sites\ $+ %site $+ \ $+ %realSiteName
  %ftpSite = $replace(%ftpSite, /, \)
  var %safeFtpSite = $replace(%ftpSite, $chr(44), $chr(32))

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) Built ftpSite path: %safeFtpSite
  }

  if (!$file(%flashfxp_path)) {
    einvite $+([,%alias,Error-,%target,]) FlashFXP executable not found at: %flashfxp_path
    return
  }

  var %myNick = $me
  var %cmd = $qt(%flashfxp_path) -raw= $+ $qt(site invite %myNick) -tray -quit $qt(%ftpSite)
  var %safeCmd = $replace(%cmd, $chr(44), $chr(32))

  if (%code) {
    einvite $+([,%alias,Code-,%target,]) Final command string: %safeCmd
  }

  run %cmd

  if (%info && %picked != $null) {
    einvite $+([,%alias,Info-,%target,]) FlashFXP started for %site on %channel (using %safeLogName)
  }

  if (%debug) {
    einvite $+([,%alias,Debug-,%target,]) Exiting isFTP
  }
}