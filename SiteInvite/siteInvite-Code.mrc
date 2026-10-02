; #####################################
; AdIRC: SiteInvite-Code              #
; Revision: 5                         #
; Date created: 05/09/2026            #
; Date last modified: 02/10/2026      #
; Author: Whiskey                     #
; #####################################

on *:START:{

  set %siteInviteConfigPath $siteinvite_config_path
  set %iniFilePath %siteInviteConfigPath

  unset %iniFileMTime

  GetData
  isCheckTimer

}

on *:CONNECT:{

  isCheckTimer

}

on *:LOAD:{

  isCheckTimer

}

on *:DISCONNECT:{

  if ($timer(siteInviteCheck)) {
    .timerSiteInviteCheck off
  }

  if ($timer(siteInviteWatchdog)) {
    .timerSiteInviteWatchdog off
  }

}

alias siteinvite_config_path {

  if (%siteInviteConfigPath) {
    return %siteInviteConfigPath
  }

  return $qt($scriptdir $+ siteInvite-Sites.dat)

}

; =========================================================
; NOTE: Intentionally NO RAW 473 handler.
; A 473 must never trigger an invite for the current user.
; The periodic isCheck routine handles User + Bot invites.
; =========================================================

alias -l einvite {

  var %msg = $1-
  var %reset = $chr(15)
  var %color

  if ($left(%msg,1) == [) {

    var %end = $pos(%msg,],1)

    if (%end) {

      var %inside = $mid(%msg,2,$calc(%end - 2))

      if (*Info* iswm %inside) {
        %color = $chr(3) $+ 3
      } elseif (*Debug* iswm %inside) {
        %color = $chr(3) $+ 7
      } elseif (*Error* iswm %inside) {
        %color = $chr(3) $+ 4
      } elseif (*Code* iswm %inside) {
        %color = $chr(3) $+ 0
      }
    }
  }

  if (%color) {
    isSynchronize $network %color $+ %msg $+ %reset
  } else {
    isSynchronize $network %msg
  }

}

; =========================================================
; GetData – loads ini into hash tables (reload only on change)
; =========================================================
alias GetData {

  if (!$isfile(%iniFilePath)) {
    return
  }

  var %currentMtime = $file(%iniFilePath).mtime

  if ((%currentMtime == %iniFileMTime) && ($hget(settings)) && ($hget(sites))) {
    return
  }

  set %iniFileMTime %currentMtime

  if ($hget(settings)) {
    hfree settings
  }

  if ($hget(sites)) {
    hfree sites
  }

  hmake settings 100
  hmake sites 1000

  ; Settings
  var %settingIndex = 1
  var %settingCount = $ini(%iniFilePath,Settings,0)

  while (%settingIndex <= %settingCount) {

    var %settingKey = $ini(%iniFilePath,Settings,%settingIndex)
    var %settingValue = $readini(%iniFilePath,Settings,%settingKey)

    hadd settings %settingKey %settingValue
    inc %settingIndex

  }

  ; Sites
  var %sectionIndex = 1
  var %sectionCount = $ini(%iniFilePath,0)

  while (%sectionIndex <= %sectionCount) {

    var %sectionName = $ini(%iniFilePath,%sectionIndex)

    if (%sectionName != Settings) {

      var %siteKeyIndex = 1
      var %siteKeyCount = $ini(%iniFilePath,%sectionName,0)

      while (%siteKeyIndex <= %siteKeyCount) {

        var %siteKey = $ini(%iniFilePath,%sectionName,%siteKeyIndex)
        var %siteValue = $readini(%iniFilePath,%sectionName,%siteKey)

        hadd sites %sectionName $+ . $+ %siteKey %siteValue
        inc %siteKeyIndex

      }
    }

    inc %sectionIndex

  }
}

alias GetSetting {

  GetData
  return $hget(settings,$1)

}

alias GetSite {

  GetData
  return $hget(sites,$1 $+ . $+ $2)

}

alias getAllSites {

  var %sites
  var %index = 1

  while ($hfind(sites,*.name,%index,w)) {

    %sites = %sites $gettok($v1,1,46)
    inc %index

  }

  return %sites

}

; =========================================================
; Watchdog – only acts / reports when the main timer is dead
; =========================================================
alias isWatchdog {

  var %lastRun = $iif(%siteInviteLastCheckRun,%siteInviteLastCheckRun,0)
  var %timePassed = $calc($ctime - %lastRun)

  if (%timePassed > 90) {

    if ($GetSetting(Error)) {
      einvite [isWatchdog-Error] CRITICAL: Main timer stopped responding (%timePassed s). Restarting...
    }

    isCheckTimer

  }

  ; intentionally silent when healthy

}

; =========================================================
; Timer management
; =========================================================
alias isCheckTimer {

  var %intervalMin = $GetSetting(CheckInterval)

  if (!%intervalMin || %intervalMin < 1) {
    %intervalMin = 1
  }

  var %intervalSec = $calc(%intervalMin * 60)

  if ($timer(siteInviteCheck)) {
    .timerSiteInviteCheck off
  }

  if ($timer(siteInviteWatchdog)) {
    .timerSiteInviteWatchdog off
  }

  .timerSiteInviteCheck 0 %intervalSec isCheck
  .timerSiteInviteWatchdog 0 60 isWatchdog

  if ($GetSetting(Debug)) {
    einvite [isTimerDebug] Main check timer started (Interval: %intervalMin min). Watchdog active.
  }

  isCheck

}

; Backward-compat aliases
alias isCheckBotTimer {
  isCheckTimer
}

alias isTimerBot {
  isCheckTimer
}

alias isCheckBot {
  isCheck
}

; =========================================================
; isCheck – core periodic logic
; =========================================================
alias isCheck {

  :error
  if ($error) {

    einvite [isCheckCrash] Crash prevented at line $scriptline : $error
    reseterror
    return

  }

  set %siteInviteLastCheckRun $ctime

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
  var %siteCount = $numtok(%sites,32)

  while (%i <= %siteCount) {

    var %site = $gettok(%sites,%i,32)
    var %siteNetwork = $GetSite(%site,network)

    if (%siteNetwork && $lower(%siteNetwork) != $lower($network)) {

      if (%debug) {
        einvite [isCheckDebug] Skipping %site - network %siteNetwork != $network
      }

    } else {

      var %botNick = $GetSite(%site,botnick)

      if (!%botNick) {
        %botNick = %globalBotNick
      }

      var %channelList = $GetSite(%site,channels)

      if (!%channelList) {

        if (%debug) {
          einvite [isCheckDebug] No channels for %site
        }

      } elseif (!%botNick) {

        if (%error) {
          einvite [isCheckError] No BotNick for %site
        }

      } else {

        var %j = 1
        var %channelCount = $numtok(%channelList,44)

        while (%j <= %channelCount) {

          var %channel = $gettok(%channelList,%j,44)

          if ($left(%channel,1) != #) {
            %channel = # $+ %channel
          }

          %channel = $lower(%channel)

          if (!$nick(%channel,$me)) {

            if (%info) {
              einvite [isCheckInfo] Whiskey is NOT in %channel
            }

            isInvite %channel User $me

          } else {

            if (!$nick(%channel,%botNick)) {

              if (%info) {
                einvite [isCheckInfo] Whiskey is in %channel
                einvite [isCheckInfo] %botNick is NOT in %channel
              }

              var %pnick = $nick(%channel,$me).pnick
              var %prefix = $left(%pnick,1)

              if (%debug) {
                einvite [isCheckDebug] Whiskey status in %channel : %pnick
              }

              if (%prefix isin ~&@%) {

                if (%info) {
                  einvite [isCheckInfo] Direct INVITE for %botNick to %channel
                }

                quote INVITE %botNick %channel

                if (%code) {
                  einvite [isCheckCode] Direct INVITE %botNick -> %channel
                }

              } else {

                if (%debug) {
                  einvite [isCheckDebug] Whiskey is normal user in %channel : %pnick
                }

                if (%info) {
                  einvite [isCheckInfo] Falling back to FlashFXP for %botNick in %channel
                }

                isInvite %channel Bot %botNick

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

; =========================================================
; isSynchronize
; =========================================================
alias isSynchronize {

  var %syncMode = $GetSetting(SyncMode)

  if (%syncMode != 0 && %syncMode != 1) {
    %syncMode = 0
  }

  var %originNetwork = $iif($1,$1,$network)
  var %message = $2-
  var %shouldOpen = 0

  if ($pos(%message,Unable to join #,1) && $pos(%message,(invite only),1)) {
    %shouldOpen = 1
  } elseif (*Error* iswm %message || *attempting invite* iswm %message || *FlashFXP started* iswm %message || *Inviting* iswm %message || *Triggering FlashFXP* iswm %message) {
    %shouldOpen = 1
  }

  var %i = 1

  while ($scon(%i)) {

    scon %i

    if ($network) {

      var %win = @Invite- $+ $network

      if ($network == %originNetwork) {

        if (!$window(%win) && %shouldOpen) {
          window -en %win
        }

        if ($window(%win)) {

          if (%syncMode == 1) {
            echo -tq %win $+([,%originNetwork,]) %message
          } else {
            echo -tq %win %message
          }
        }

      } elseif (%syncMode == 1 && $window(%win)) {
        echo -tq %win $+([,%originNetwork,]) %message
      }
    }

    inc %i

  }
}

; =========================================================
; isInvite
; =========================================================
alias isInvite {

  var %debug = $GetSetting(Debug)
  var %error = $GetSetting(Error)
  var %info = $GetSetting(Info)

  var %target = $upper($iif($2,$2,User))
  var %targetNick = $3

  if (%target == USER) {

    %target = User

    if (!%targetNick) {
      %targetNick = $me
    }
  } elseif (%target == BOT) {

    %target = Bot

    if (!%targetNick) {

      %targetNick = $GetSite($1,botnick)

      if (!%targetNick) {
        %targetNick = $GetSetting(BotNick)
      }
    }
  } else {

    if (%error) {
      einvite [isInviteError] Unknown target: %target
    }

    return

  }

  var %channel = $iif($1,$1,$strip($gettok($rawmsg,4,32)))

  if (!%channel) {

    if (%error) {
      einvite $+([isInviteError-,%target,]) Unable to determine channel
    }

    return

  }

  if ($left(%channel,1) != #) {
    %channel = # $+ %channel
  }

  %channel = $lower(%channel)

  if (!%targetNick) {

    if (%error) {
      einvite $+([isInviteError-,%target,]) Missing target nick for %target in %channel
    }

    return

  }

  ; Bot invites require us to be present
  if (%target == Bot && !$nick(%channel,$me)) {

    if (%debug) {
      einvite $+([isInviteDebug-Bot,]) $me not in %channel - refusing Bot invite
    }

    return

  }

  if ($nick(%channel,%targetNick)) {

    if (%info) {
      einvite $+([isInviteInfo-,%target,]) %targetNick already in %channel - skipping
    }

    return

  }

  var %siteResult = $isSite(%channel)
  var %result = $gettok(%siteResult,1,32)

  if (%result == 0) {

    if (%error) {
      einvite $+([isInviteError-,%target,]) No site found for %channel
    }

    return

  }

  var %site = $gettok(%siteResult,2,32)
  var %name = $gettok(%siteResult,3,32)

  if (%debug) {
    einvite $+([isInviteDebug-,%target,]) Site resolved: %site ( %name ) for %channel
  }

  if ($isTimer(%site,%target)) {

    if (%debug) {
      einvite $+([isInviteDebug-,%target,]) Cooldown active for %site - skipping
    }

    return

  }

  ; Final safety
  if (%target == Bot && !$nick(%channel,$me)) {
    return
  }

  if ($nick(%channel,%targetNick)) {

    if (%info) {
      einvite $+([isInviteInfo-,%target,]) %targetNick joined before invite - skipping
    }

    return

  }

  if (%debug) {
    einvite $+([isInviteDebug-,%target,]) Starting FTP invite: site= %site channel = %channel target = %target targetNick = %targetNick
  }

  isFTP %site %channel %target %targetNick

}

; =========================================================
; isSite
; =========================================================
alias isSite {

  var %channel = $1
  var %debug = $GetSetting(Debug)
  var %sitesList = $getAllSites
  var %siteCount = $numtok(%sitesList,32)
  var %i = 1

  while (%i <= %siteCount) {

    var %site = $gettok(%sitesList,%i,32)
    var %siteNetwork = $GetSite(%site,network)

    if (!%siteNetwork || $lower(%siteNetwork) == $lower($network)) {

      var %channels = $GetSite(%site,channels)
      var %normChannels
      var %chIdx = 1
      var %chCnt = $numtok(%channels,44)

      while (%chIdx <= %chCnt) {

        var %cTok = $gettok(%channels,%chIdx,44)

        if ($left(%cTok,1) != #) {
          %cTok = # $+ %cTok
        }

        %normChannels = $addtok(%normChannels,$lower(%cTok),44)
        inc %chIdx

      }

      if ($istok(%normChannels,$lower(%channel),44)) {
        if ($GetSite(%site,ignore_entire) == 1) {

          if (%debug) {
            einvite [isSite-Debug] Site %site entirely ignored
          }

          return 0

        }

        if (%debug) {
          einvite [isSite-Debug] Site resolved: %site ( $+ $GetSite(%site,name) $+ ) for %channel
        }

        return 1 %site $GetSite(%site,name)

      }
    }

    inc %i

  }

  if (%debug) {
    einvite [isSite-Debug] Unknown channel: %channel
  }

  return 0

}

; =========================================================
; isTimer – per-site cooldown
; =========================================================
alias isTimer {

  var %site = $1
  var %target = $iif($2,$2,User)
  var %debug = $GetSetting(Debug)

  if (!$hget(inviteTimers)) {
    hmake inviteTimers 20
  }

  var %key = %site $+ . $+ %target
  var %lastTime = $hget(inviteTimers,%key)

  if (%lastTime) {

    var %timePassed = $calc($ctime - %lastTime)

    if (%timePassed < 60) {

      if (%debug) {

        var %tag = isTimerDebug- $+ %target

        einvite $+([,%tag,]) %site cooldown active: $calc(60 - %timePassed)s left

      }

      return 1

    }
  }

  hadd inviteTimers %key $ctime

  if (%debug) {

    var %tag = isTimerDebug- $+ %target

    einvite $+([,%tag,]) No active timer for %site

  }

  return 0

}

; =========================================================
; isFTP – FlashFXP invite
; =========================================================
alias isFTP {

  var %alias = isFTP
  var %site = $1
  var %channel = $2
  var %argument3 = $3
  var %argument4 = $4
  var %target
  var %targetNick
  var %testMode = 0

  :error
  if ($error) {

    einvite $+([,%alias,-Crash $chr(124) %target,]) line $scriptline : $error
    reseterror
    return

  }

  if (%argument3 == User || %argument3 == Bot) {

    %target = %argument3
    %targetNick = %argument4

  } else {

    %targetNick = %argument3
    %target = $iif(%targetNick == $me,User,Bot)

  }

  if (%argument4 == setting) {
    %testMode = 1
  }

  if (!%site) {

    einvite $+([,%alias,-Error $chr(124) %target,]) Missing site parameter
    return

  }

  var %debug = $GetSetting(Debug)
  var %info = $GetSetting(Info)
  var %code = $GetSetting(Code)
  var %error = $GetSetting(Error)

  if (%debug) {
    einvite $+([,%alias,-Debug $chr(124) %target,]) Entering isFTP site = %site channel = %channel
  }

  var %flashFxpPath = $GetSetting(FlashFXPPath)

  if (%code) {
    einvite $+([,%alias,-Debug $chr(124) %target,]) flashFxpPath: %flashFxpPath
  }

  if (%info) {
    einvite $+([,%alias,-Info $chr(124) %target,]) Triggering FlashFXP for %site / %channel
  }

  if (!%testMode) {
    if (!%targetNick) {

      einvite $+([,%alias,-Error $chr(124) %target,]) Missing target nick - skipping
      return

    }

    if ($nick(%channel,%targetNick)) {

      if (%error) {
        einvite $+([,%alias,-Error $chr(124) %target,]) %targetNick already in %channel - skipping
      }

      return

    }
  }

  ; Synchronize Sites.dat
  var %localDat = $scriptdir $+ SiteInvite-Sites.dat
  var %flashPath = $GetSetting(FlashAppData)

  if (!%flashPath) {
    %flashPath = $envvar(APPDATA) $+ \FlashFXP\5\
  }

  %flashPath = $remove(%flashPath,$chr(34))

  if (%flashPath && $right(%flashPath,1) != \) {
    %flashPath = %flashPath $+ \
  }

  var %srcDat = %flashPath $+ Sites.dat

  if (!$isfile(%srcDat)) {

    var %searchRoot = $envvar(APPDATA)

    if (%searchRoot && $isdir(%searchRoot)) {
      %srcDat = $findfile(%searchRoot,Sites.dat,1,10)
    }

  }

  if (%srcDat && $isfile(%srcDat)) {

    var %srcMtime = $file(%srcDat).mtime
    var %localMtime = $iif($isfile(%localDat),$file(%localDat).mtime,0)

    if (!$isfile(%localDat) || %srcMtime != %localMtime) {

      copy -o $qt(%srcDat) $qt(%localDat)

      if (!$isfile(%localDat) && %error) {

        einvite $+([,%alias,-Error $chr(124) %target,]) Could not copy FlashFXP database
        return

      }

      if (%code) {
        einvite $+([,%alias,-Code $chr(124) %target,]) Updated local FlashFXP database
      }

    }

  } elseif (%error) {
    einvite $+([,%alias,-Error $chr(124) %target,]) FlashFXP Sites.dat not found
  }

  ; Filter ftpsites
  var %ftpSites = $GetSite(%site,ftpsites)
  var %ftpSitesIgnore = $GetSite(%site,ftpsites_ignore)

  if (%ftpSitesIgnore != $null && %ftpSites != $null) {

    var %validList
    var %totalSites = $numtok(%ftpSites,44)
    var %i = 1

    while (%i <= %totalSites) {

      var %currSite = $gettok(%ftpSites,%i,44)
      var %cleanCurr = $regsubex($remove(%currSite,*),/^\s+|\s+$/g,$null)
      var %isIgnored = $false
      var %ignoreCount = $numtok(%ftpSitesIgnore,44)
      var %ig = 1

      while (%ig <= %ignoreCount) {

        var %ign = $gettok(%ftpSitesIgnore,%ig,44)
        var %cleanIgn = $regsubex($remove(%ign,*),/^\s+|\s+$/g,$null)

        if (%cleanCurr == %cleanIgn) {

          %isIgnored = $true
          break

        }

        inc %ig

      }

      if (!%isIgnored) {
        %validList = $addtok(%validList,%currSite,44)
      }

      inc %i

    }

    %ftpSites = %validList

  }

  ; Remove offline
  var %onlineFtpSites
  var %offlineList
  var %offlineCount = 0
  var %s = 1
  var %totalFtpCount = $numtok(%ftpSites,44)

  while (%s <= %totalFtpCount) {

    var %siteItem = $gettok(%ftpSites,%s,44)
    var %cleanItem = $regsubex($remove(%siteItem,*),/^\s+|\s+$/g,$null)
    var %isOffline = $false

    if (*[Offline]* iswm %siteItem || *[Offline]* iswm %cleanItem) {
      %isOffline = $true
    }

    if (!%isOffline && $isfile(%localDat)) {

      var %l = 1
      var %totLines = $lines(%localDat)

      while (%l <= %totLines) {

        var %line = $read(%localDat,%l)

        if (* $+ %cleanItem $+ * iswm %line && *[Offline]* iswm %line) {

          %isOffline = $true
          break

        }

        inc %l

      }
    }

    if (%isOffline) {

      %offlineList = $addtok(%offlineList,%cleanItem,44)
      inc %offlineCount

    } else {
      %onlineFtpSites = $addtok(%onlineFtpSites,%siteItem,44)
    }

    inc %s

  }

  if (%code) {
    einvite $+([,%alias,-Code $chr(124) %target,]) FTP sites offline: $iif(%offlineList,$replace(%offlineList,$chr(44),$chr(32)),none) ( $+ %offlineCount $+ / $+ %totalFtpCount $+ )
  }

  %ftpSites = %onlineFtpSites

  var %remainingCount = $numtok(%ftpSites,44)

  if (!%remainingCount) {

    einvite $+([,%alias,-Error $chr(124) %target,]) No valid ftpsites for %site
    return

  }

  var %randIndex = $rand(1,%remainingCount)
  var %picked = $gettok(%ftpSites,%randIndex,44)

  if (%code) {
    einvite $+([,%alias,-Code $chr(124) %target,]) Picked: %picked
  }

  var %cleanKey = $regsubex($remove(%picked,*),/^\s+|\s+$/g,$null)

  ; Resolve real site name
  var %iniFile = $GetSetting(ConfigFile)

  if (!%iniFile) {
    %iniFile = settings.ini
  }

  var %realSiteName = $readini(%iniFile,n,siteInvite-FlashFXP,%cleanKey)

  if (!%realSiteName) {
    %realSiteName = $readini(%iniFile,n,siteInvite-FlashFXP,%picked)
  }

  if (!%realSiteName && $isfile(%localDat)) {

    var %lineNo = 1
    var %totL = $lines(%localDat)

    while (%lineNo <= %totL) {

      var %lineContent = $read(%localDat,%lineNo)

      if (* $+ %cleanKey $+ * iswm %lineContent && *[Offline]* !iswm %lineContent) {

        var %cleanLine = %lineContent

        if ($left(%cleanLine,1) == [) {
          %cleanLine = $mid(%cleanLine,2)
        }

        if ($right(%cleanLine,1) == ]) {
          %cleanLine = $left(%cleanLine,-1)
        }

        %cleanLine = $regsubex($regsubex(%cleanLine,/[\x00-\x1F\x7F]/g,\),/\\+/g,\)

        var %extracted = $regsubex($gettok(%cleanLine,-1,92),/^\s+|\s+$/g,$null)

        if (%extracted) {

          %realSiteName = %extracted
          break

        }
      }

      inc %lineNo

    }
  }

  if (!%realSiteName) {
    %realSiteName = %cleanKey
  }

  var %ftpSitePath = Sites\ $+ %site $+ \ $+ %realSiteName
  %ftpSitePath = $replace(%ftpSitePath,/,\)

  if (%code) {
    einvite $+([,%alias,-Code $chr(124) %target,]) Resolved profile: $replace(%realSiteName,$chr(44),$chr(32))
    einvite $+([,%alias,-Code $chr(124) %target,]) Built path: $replace(%ftpSitePath,$chr(44),$chr(32))
  }

  if (!$file(%flashFxpPath)) {

    einvite $+([,%alias,-Error $chr(124) %target,]) FlashFXP not found at: %flashFxpPath
    return

  }

  var %cmd = $qt(%flashFxpPath) -raw= $+ $qt(site invite $me) -tray -quit $qt(%ftpSitePath)

  if (%code) {
    einvite $+([,%alias,-Code $chr(124) %target,]) Command: $replace(%cmd,$chr(44),$chr(32))
  }

  run %cmd

  if (%info) {
    einvite $+([,%alias,-Info $chr(124) %target,]) FlashFXP started for %site on %channel (using $replace(%realSiteName,$chr(44),$chr(32)))
  }

  if (%debug) {
    einvite $+([,%alias,-Debug $chr(124) %target,]) Exiting isFTP
  }
}