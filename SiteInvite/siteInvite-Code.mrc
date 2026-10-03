; #####################################
; AdIRC: SiteInvite-Code              #
; Revision: 6                         #
; Date created: 05/09/2026            #
; Date last modified: 03/10/2026      #
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

  return $qt($scriptdir $+ siteInvite-Config.ini)

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
; Normalize channel CSV data.
; Storage is comma-separated and may contain an accidental second '#' when
; older interface versions concatenated channel rows. Treat that '#' as a
; channel boundary so malformed legacy data cannot become a real IRC target.
; =========================================================
alias siteinvite_normalize_channels {

  var %input = $1-
  var %output
  var %i = 1
  var %count = $numtok(%input,44)

  while (%i <= %count) {

    var %token = $gettok(%input,%i,44)

    while ($left(%token,1) == $chr(32)) {
      %token = $mid(%token,2)
    }

    while ($right(%token,1) == $chr(32)) {
      %token = $left(%token,$calc($len(%token)-1))
    }

    if (%token) {

      ; A channel starts with '#'. An additional '#' indicates an
      ; accidentally concatenated channel from malformed legacy data.
      while ($left(%token,1) == #) {
        %token = $mid(%token,2)
      }

      while ($pos(%token,#,1)) {

        var %hashPos = $pos(%token,#,1)
        var %leftPart = $left(%token,$calc(%hashPos - 1))
        var %rightPart = $mid(%token,$calc(%hashPos + 1))

        if (%leftPart) {
          %output = $addtok(%output,%leftPart,44)
        }

        %token = %rightPart

      }

      if (%token) {
        %output = $addtok(%output,%token,44)
      }
    }

    inc %i

  }

  return $sorttok(%output,44)

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

  var %alias = isWatchdog
  var %target = System

  var %lastRun = $iif(%siteInviteLastCheckRun,%siteInviteLastCheckRun,0)
  var %timePassed = $calc($ctime - %lastRun)

  if (%timePassed > 90) {

    if ($GetSetting(Error)) {
      einvite $+([,%alias,-Error $chr(124) %target,]) CRITICAL: Main timer stopped responding (%timePassed s). Restarting...
    }

    isCheckTimer

  }

  ; intentionally silent when healthy

}

; =========================================================
; Timer management
; =========================================================

alias isCheckTimer {

  var %alias = isCheckTimer
  var %target = System

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
    einvite $+([,%alias,-Debug $chr(124) %target,]) Main check timer started (Interval: %intervalMin min). Watchdog active.
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

  var %alias = isCheck
  var %target = User

  :error
  if ($error) {

    einvite $+([,%alias,-Crash $chr(124) %target,]) Crash prevented at line $scriptline : $error
    reseterror
    return

  }

  set %siteInviteLastCheckRun $ctime

  ; The interface can change the INI independently of this script.
  ; Reload once at the start of every periodic run so inactive Site/Channel
  ; states are never hidden behind a stale mtime cache.
  unset %iniFileMTime
  GetData

  var %debug = $GetSetting(Debug)
  var %info = $GetSetting(Info)
  var %error = $GetSetting(Error)
  var %code = $GetSetting(Code)
  var %globalNick = $GetSetting(Nick)
  var %globalBotNick = $GetSetting(BotNick)
  var %sites = $getAllSites

  var %checkUser = $GetSetting(CheckUser)
  var %checkBot = $GetSetting(CheckBot)

  if (%checkUser == $null) {
    %checkUser = 1
  }

  if (%checkBot == $null) {
    %checkBot = 1
  }

  ; isCheck messages use the first enabled check as the target context.
  ; User is shown when the User check is enabled; otherwise Bot is shown.
  var %checkTarget = $iif(%checkUser,User,Bot)
  %target = %checkTarget

  if (!%sites) {

    if (%error) {
      einvite $+([,%alias,-Error $chr(124) %target,]) No sites configured
    }

    return

  }

  if (!%checkUser && !%checkBot) {
    return
  }

  var %i = 1
  var %siteCount = $numtok(%sites,32)

  while (%i <= %siteCount) {

    var %site = $gettok(%sites,%i,32)
    var %siteNetwork = $GetSite(%site,network)

    if (%siteNetwork && $lower(%siteNetwork) != $lower($network)) {

      if (%debug) {
        einvite $+([,%alias,-Debug $chr(124) %target,]) Skipping %site - network %siteNetwork != $network
      }

    } elseif ($GetSite(%site,ignore_entire) == 1) {

      if (%error) {
        einvite $+([,%alias,-Error $chr(124) %target,]) Site %site is configured but inactive - skipping
      }

    } else {

      var %botNick = $GetSite(%site,botnick)
      var %userNick = $GetSite(%site,usernick)

      if (!%botNick) {
        %botNick = %globalBotNick
      }

      if (!%userNick) {
        %userNick = %globalNick
      }

      if (!%userNick) {
        %userNick = $me
      }

      var %channelList = $GetSite(%site,channels)
      %channelList = $siteinvite_normalize_channels(%channelList)

      if (!%channelList) {

        if (%debug) {
          einvite $+([,%alias,-Debug $chr(124) %target,]) No channels for %site
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

          ; The "ignore" key contains only INACTIVE channels.
          ; A channel is active when it is in "channels" and NOT in "ignore".
          var %ignoredChannels = $siteinvite_normalize_channels($GetSite(%site,ignore))
          var %channelIgnored = 0
          var %ignoreIndex = 1
          var %ignoreCount = $numtok(%ignoredChannels,44)

          while (%ignoreIndex <= %ignoreCount) {

            var %ignoredChannel = $gettok(%ignoredChannels,%ignoreIndex,44)

            if ($left(%ignoredChannel,1) != #) {
              %ignoredChannel = # $+ %ignoredChannel
            }

            if ($lower(%ignoredChannel) == %channel) {
              %channelIgnored = 1
              break
            }

            inc %ignoreIndex

          }

          if (%channelIgnored) {

            if (%error) {
              einvite $+([,%alias,-Error $chr(124) %target,]) Channel %channel is configured for site %site but inactive - skipping
            }

            inc %j
            continue

          }

          ; User check is performed only when enabled.
          if (%checkUser) {

            %target = User

            if (!$nick(%channel,%userNick)) {

              if (%info) {
                einvite $+([,%alias,-Info $chr(124) %target,]) %userNick is NOT in %channel
              }

              if (%debug) {
                einvite $+([,%alias,-Debug $chr(124) %target,]) Check failed: %userNick is not in %channel on $network (Site: %site $+ $chr(41))
              }

              isInvite %channel User %userNick

              inc %j
              continue

            }
          }

          ; Bot check is performed only when enabled.
          if (%checkBot) {

            %target = Bot

            if (!%botNick) {

              if (%error) {
                einvite $+([,%alias,-Error $chr(124) %target,]) No BotNick configured for %site
              }

              inc %j
              continue

            }

            if (!$nick(%channel,%botNick)) {

              if (%info) {
                einvite $+([,%alias,-Info $chr(124) %target,]) %botNick is NOT in %channel
              }

              var %pnick = $nick(%channel,$me).pnick
              var %prefix = $left(%pnick,1)

              ; We need to be present in the channel before a direct IRC INVITE.
              if ($nick(%channel,$me)) {

                if (%prefix isin ~&@%) {

                  if (%info) {
                    einvite $+([,%alias,-Info $chr(124) %target,]) Direct INVITE for %botNick to %channel
                  }

                  quote INVITE %botNick %channel

                  if (%code) {
                    einvite $+([,%alias,-Code $chr(124) %target,]) Direct INVITE %botNick -> %channel
                  }

                } else {

                  if (%info) {
                    einvite $+([,%alias,-Info $chr(124) %target,]) Falling back to FlashFXP for %botNick in %channel
                  }

                  isInvite %channel Bot %botNick

                }
              } else {

                if (%debug) {
                  einvite $+([,%alias,-Debug $chr(124) %target,]) Cannot check/invite %botNick in %channel because $me is not present
                }
              }

              inc %j
              continue

            }
          }

          ; User and Bot checks passed. Stay silent.
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

  var %alias = isInvite

  var %debug = $GetSetting(Debug)
  var %error = $GetSetting(Error)
  var %info = $GetSetting(Info)

  var %target = $upper($iif($2,$2,User))
  var %targetNick = $3

  if (%target == USER) {

    %target = User

    if (!%targetNick) {
      %targetNick = $GetSite($1,usernick)
    }

    if (!%targetNick) {
      %targetNick = $GetSetting(Nick)
    }

    if (!%targetNick) {
      %targetNick = $me
    }

  } elseif (%target == BOT) {

    %target = Bot

    if (!%targetNick) {
      %targetNick = $GetSite($1,botnick)
    }

    if (!%targetNick) {
      %targetNick = $GetSetting(BotNick)
    }

  } else {

    if (%error) {
      einvite $+([,%alias,-Error $chr(124) %target,]) Unknown target: %target
    }

    return

  }

  var %channel = $iif($1,$1,$strip($gettok($rawmsg,4,32)))

  if (!%channel) {

    if (%error) {
      einvite $+([,%alias,-Error $chr(124) %target,]) Unable to determine channel
    }

    return

  }

  if ($left(%channel,1) != #) {
    %channel = # $+ %channel
  }

  %channel = $lower(%channel)

  if (!%targetNick) {

    if (%error) {
      einvite $+([,%alias,-Error $chr(124) %target,]) Missing target nick for %target in %channel
    }

    return

  }

  ; Bot invites require us to be present in the channel.
  if (%target == Bot && !$nick(%channel,$me)) {

    if (%debug) {
      einvite $+([,%alias,-Debug $chr(124) %target,]) $me not in %channel - refusing Bot invite
    }

    return

  }

  if ($nick(%channel,%targetNick)) {

    if (%info) {
      einvite $+([,%alias,-Info $chr(124) %target,]) %targetNick already in %channel - skipping
    }

    return

  }

  var %siteResult = $isSite(%channel,%target)
  var %result = $gettok(%siteResult,1,32)

  if (%result == 0) {

    if (%error) {
      einvite $+([,%alias,-Error $chr(124) %target,]) No active site found for %channel
    }

    return

  }

  var %site = $gettok(%siteResult,2,32)
  var %name = $gettok(%siteResult,3,32)

  if (%debug) {
    einvite $+([,%alias,-Debug $chr(124) %target,]) Site resolved: %site ( $+ %name $+ ) for %channel
  }

  if ($isTimer(%site,%target)) {

    if (%debug) {
      einvite $+([,%alias,-Debug $chr(124) %target,]) Cooldown active for %site - skipping
    }

    return

  }

  ; Final safety checks before starting FTP.
  if (%target == Bot && !$nick(%channel,$me)) {
    return
  }

  if ($nick(%channel,%targetNick)) {

    if (%info) {
      einvite $+([,%alias,-Info $chr(124) %target,]) %targetNick joined before invite - skipping
    }

    return

  }

  if (%debug) {
    einvite $+([,%alias,-Debug $chr(124) %target,]) Starting FTP invite: $+($chr(40),Site: %site $chr(124) Channel: %channel $chr(124) Target: User / %targetNick,$chr(41))
  }

  isFTP %site %channel %target %targetNick

}

; =========================================================
; isSite
; =========================================================

alias isSite {

  var %alias = isSite
  var %target = $2

  if (%target != User && %target != Bot) {
    %target = System
  }

  var %channel = $1
  var %debug = $GetSetting(Debug)
  var %error = $GetSetting(Error)
  var %sitesList = $getAllSites
  var %siteCount = $numtok(%sitesList,32)
  var %i = 1
  var %inactiveSiteFound = 0
  var %inactiveChannelFound = 0
  var %inactiveSiteName
  var %inactiveChannelSite

  if ($left(%channel,1) != #) {
    %channel = # $+ %channel
  }

  %channel = $lower(%channel)

  while (%i <= %siteCount) {

    var %site = $gettok(%sitesList,%i,32)
    var %siteNetwork = $GetSite(%site,network)

    if (!%siteNetwork || $lower(%siteNetwork) == $lower($network)) {

      var %channels = $siteinvite_normalize_channels($GetSite(%site,channels))
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

      if ($istok(%normChannels,%channel,44)) {
        if ($GetSite(%site,ignore_entire) == 1) {

          %inactiveSiteFound = 1
          %inactiveSiteName = %site

        } else {

          var %ignoredChannels = $siteinvite_normalize_channels($GetSite(%site,ignore))
          var %ignoreIndex = 1
          var %ignoreCount = $numtok(%ignoredChannels,44)
          var %isIgnored = 0

          while (%ignoreIndex <= %ignoreCount) {

            var %ignoredChannel = $gettok(%ignoredChannels,%ignoreIndex,44)

            if ($left(%ignoredChannel,1) != #) {
              %ignoredChannel = # $+ %ignoredChannel
            }

            if ($lower(%ignoredChannel) == %channel) {
              %isIgnored = 1
              break
            }

            inc %ignoreIndex

          }

          if (%isIgnored) {

            %inactiveChannelFound = 1
            %inactiveChannelSite = %site

          } else {

            if (%debug) {
              einvite $+([,%alias,-Debug $chr(124) %target,]) Site resolved: %site ( $+ $GetSite(%site,name) $+ ) for %channel
            }

            return 1 %site $GetSite(%site,name)

          }
        }
      }
    }

    inc %i

  }

  if (%error) {

    if (%inactiveChannelFound) {
      einvite $+([,%alias,-Error $chr(124) %target,]) Channel %channel is configured for site %inactiveChannelSite but inactive
    } elseif (%inactiveSiteFound) {
      einvite $+([,%alias,-Error $chr(124) %target,]) Site %inactiveSiteName is configured for %channel but inactive
    } else {
      einvite $+([,%alias,-Error $chr(124) %target,]) No active site/channel found for %channel
    }

  } elseif (%debug) {

    if (%inactiveChannelFound) {
      einvite $+([,%alias,-Debug $chr(124) %target,]) Channel %channel is inactive for site %inactiveChannelSite
    } elseif (%inactiveSiteFound) {
      einvite $+([,%alias,-Debug $chr(124) %target,]) Site %inactiveSiteName is inactive for %channel
    } else {
      einvite $+([,%alias,-Debug $chr(124) %target,]) Unknown or inactive channel: %channel
    }
  }

  return 0

}

; =========================================================
; isTimer – per-site cooldown
; =========================================================

alias isTimer {

  var %alias = isTimer
  var %target = $iif($2,$2,System)

  var %site = $1
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
        einvite $+([,%alias,-Debug $chr(124) %target,]) %site cooldown active: $calc(60 - %timePassed)s left
      }

      return 1

    }
  }

  hadd inviteTimers %key $ctime

  if (%debug) {
    einvite $+([,%alias,-Debug $chr(124) %target,]) No active timer for %site
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

    if (!%targetNick) {
      %targetNick = $GetSite(%site,usernick)
    }

    if (!%targetNick) {
      %targetNick = $GetSetting(Nick)
    }

    if (!%targetNick) {
      %targetNick = $me
    }

    %target = User

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
  var %ftpCheck = $GetSetting(FTPCheck)

  ; FTPUser is independent from the IRC target nick. A site-specific FTPUser
  ; overrides the global FTPUser, and the IRC target nick remains the final
  ; backward-compatible fallback when no FTPUser is configured.
  var %ftpUser = $GetSite(%site,ftpuser)

  if (!%ftpUser) {
    %ftpUser = $GetSetting(FTPUser)
  }

  if (!%ftpUser) {
    %ftpUser = %targetNick
  }

  ; isFTP is a final execution boundary. Never start FlashFXP unless both
  ; the Site and Channel are active. This protects manual/direct isFTP calls.
  var %siteEnabled = $GetSite(%site,ignore_entire)

  if (%siteEnabled == 1) {

    if (%error) {
      einvite $+([,%alias,-Error $chr(124) %target,]) Site %site is inactive - FTP invite refused
    }

    return

  }

  var %channelState = $isSite(%channel,%target)

  if ($gettok(%channelState,1,32) != 1 || $lower($gettok(%channelState,2,32)) != $lower(%site)) {
    return
  }

  var %userNick = $GetSite(%site,usernick)

  if (!%userNick) {
    %userNick = $GetSetting(Nick)
  }

  if (!%userNick) {
    %userNick = $me
  }

  if (%ftpCheck == $null) {
    %ftpCheck = 0
  }

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

  ; Optional target-presence verification is controlled by the GUI via FTPCheck.
  if (!%testMode && %ftpCheck) {

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

  ; Filter FTP sites.
  ; The "ftpsites_ignore" key contains only INACTIVE FTP-sites.
  ; Keep configured/inactive/active counts separate so reporting never
  ; turns an inactive-only list into a misleading 0/0 result.
  var %ftpSites = $GetSite(%site,ftpsites)
  var %ftpSitesIgnore = $GetSite(%site,ftpsites_ignore)
  var %configuredFtpCount = 0
  var %inactiveFtpCount = 0
  var %inactiveFtpList
  var %activeFtpSites

  if (%ftpSites != $null) {

    %configuredFtpCount = $numtok(%ftpSites,44)

    var %i = 1
    var %ignoreCount = $numtok(%ftpSitesIgnore,44)

    while (%i <= %configuredFtpCount) {

      var %currSite = $gettok(%ftpSites,%i,44)
      var %cleanCurr = $regsubex($remove(%currSite,*),/^\s+|\s+$/g,$null)
      var %isIgnored = $false
      var %ig = 1

      while (%ig <= %ignoreCount) {

        var %ignoredItem = $gettok(%ftpSitesIgnore,%ig,44)
        var %cleanIgnored = $regsubex($remove(%ignoredItem,*),/^\s+|\s+$/g,$null)

        if ($lower(%cleanCurr) == $lower(%cleanIgnored)) {
          %isIgnored = $true
          break
        }

        inc %ig

      }

      if (%isIgnored) {
        inc %inactiveFtpCount
        %inactiveFtpList = $addtok(%inactiveFtpList,%currSite,44)
      } else {
        %activeFtpSites = $addtok(%activeFtpSites,%currSite,44)
      }

      inc %i

    }
  }

  var %activeFtpCount = $numtok(%activeFtpSites,44)
  %ftpSites = %activeFtpSites

  if (%code) {

    einvite $+([,%alias,-Code $chr(124) %target,]) FTP-Sites configured: %configuredFtpCount $chr(124) Active: %activeFtpCount $chr(124) Inactive: %inactiveFtpCount

    if (%inactiveFtpList) {
      einvite $+([,%alias,-Code $chr(124) %target,]) Inactive FTP-Sites: $replace(%inactiveFtpList,$chr(44),$chr(32))
    }
  }

  if (!%configuredFtpCount) {
    einvite $+([,%alias,-Error $chr(124) %target,]) No FTP-Sites configured for %site
    return
  }

  if (!%activeFtpCount) {

    if (%inactiveFtpList) {
      einvite $+([,%alias,-Error $chr(124) %target,]) All FTP-Sites for %site are inactive: $replace(%inactiveFtpList,$chr(44),$chr(32))
    } else {
      einvite $+([,%alias,-Error $chr(124) %target,]) No active FTP-Sites available for %site
    }

    return

  }

  ; Remove offline active FTP-Sites.
  var %onlineFtpSites
  var %offlineList
  var %offlineCount = 0
  var %s = 1
  var %totalFtpCount = %activeFtpCount

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
      %offlineList = $addtok(%offlineList,%siteItem,44)
      inc %offlineCount
    } else {
      %onlineFtpSites = $addtok(%onlineFtpSites,%siteItem,44)
    }

    inc %s

  }

  if (%code) {

    einvite $+([,%alias,-Code $chr(124) %target,]) FTP-Sites online: $numtok(%onlineFtpSites,44) $chr(124) offline: %offlineCount $chr(124) active: %activeFtpCount

    if (%offlineList) {
      einvite $+([,%alias,-Code $chr(124) %target,]) Offline FTP-Sites: $replace(%offlineList,$chr(44),$chr(32))
    }
  }

  %ftpSites = %onlineFtpSites

  var %remainingCount = $numtok(%ftpSites,44)

  if (!%remainingCount) {
    einvite $+([,%alias,-Error $chr(124) %target,]) All active FTP-Sites for %site are offline: $replace(%offlineList,$chr(44),$chr(32))
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

  var %cmd = $qt(%flashFxpPath) -raw= $+ $qt(site invite %ftpUser) -tray -quit $qt(%ftpSitePath)

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