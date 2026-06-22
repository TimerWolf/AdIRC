;######################################
; AdIRC: SiteInvite-Code              #
; Revision: 1                         #
; Date created: 05/09/2026            #
; Date last modified: 05/09/2026      #
; Author: Whiskey                     #
; #####################################

; ----------------------------------------
; START
; ----------------------------------------

on *:START:{

  ; ----------------------------------------
  ; Set default variables
  ; ----------------------------------------

  ; Set file path
  set %iniFilePath $qt($scriptdir $+ siteInvite-Sites.dat)

  ; Unset saved time
  unset %iniFileMTime

  ; ----------------------------------------
  ; Get values from data file
  ; ----------------------------------------

  GetData

  ; ----------------------------------------
  ; Timers
  ; ----------------------------------------

  isCheckBotTimer

}

; ----------------------------------------
; Redirect Invite Messages
; ----------------------------------------

; Get invite messages
RAW 473:*:{

  ; Broadcast the invite-only error to the originating network and sync to all open windows
  isSynchronize $network Unable to join $2 (invite only)

  ; Run invite script
  isInvite

  ; Stop script execution
  halt

}

; Returns the custom @Invite window name for current network
alias -l einvite {

  ; Set variables
  var %msg = $1-
  var %reset = $chr(15)
  var %color

  ; Must start with [
  if ($left(%msg,1) == [) {

    var %end = $pos(%msg,],1)

    if (%end) {

      var %inside = $mid(%msg,2,$calc(%end - 2))
      var %suffix = $gettok(%inside,$numtok(%inside,45),45)

      ; Set color
      if (%suffix == Info)  {
        %color = $chr(3) $+ 3
      } elseif (%suffix == Debug) {
        %color = $chr(3) $+ 7
      } elseif (%suffix == Error) {
        %color = $chr(3) $+ 4
      } elseif (%suffix == Code) {
        %color = $chr(3) $+ 0
      }
    }
  }

  ; Check what massage to send
  if (%color) {
    isSynchronize $network %color $+ %msg $+ %reset
  } else {
    isSynchronize $network %msg
  }
}

; =========================================================
; GetData: (loads the ini file into hash tables, yses caching: reloads only if the file has changed)
; =========================================================

alias GetData {

  ; -------------------------------------------------------
  ; Safety check: ini file must exist
  ; -------------------------------------------------------

  if (!$isfile(%iniFilePath)) {
    return
  }

  ; -------------------------------------------------------
  ; Cache validation: reload only if file changed
  ; -------------------------------------------------------

  var %current_mtime = $file(%iniFilePath).mtime

  if ((%current_mtime == %iniFileMTime) && ($hget(settings)) && ($hget(sites))) {
    return
  }

  set %iniFileMTime %current_mtime

  ; -------------------------------------------------------
  ; Reset hash tables
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
  ; Load settings section
  ; =======================================================

  var %setting_index = 1
  var %setting_count = $ini(%iniFilePath, Settings, 0)

  while (%setting_index <= %setting_count) {

    var %setting_key   = $ini(%iniFilePath, Settings, %setting_index)
    var %setting_value = $readini(%iniFilePath, Settings, %setting_key)

    hadd settings %setting_key %setting_value

    inc %setting_index

  }

  ; =======================================================
  ; Load all site sections (everything except settings)
  ; =======================================================
  var %section_index = 1
  var %section_count = $ini(%iniFilePath, 0)

  while (%section_index <= %section_count) {

    var %section_name = $ini(%iniFilePath, %section_index)

    ; Skip settings section
    if (%section_name != Settings) {

      var %site_key_index = 1
      var %site_key_count = $ini(%iniFilePath, %section_name, 0)

      while (%site_key_index <= %site_key_count) {

        var %site_key   = $ini(%iniFilePath, %section_name, %site_key_index)
        var %site_value = $readini(%iniFilePath, %section_name, %site_key)

        ; Stored as: SiteName.Key
        hadd sites %section_name $+ . $+ %site_key %site_value

        inc %site_key_index

      }
    }

    inc %section_index

  }
}

; ----------------------------------------
; Alias: GetSetting
; Description: returns a value from the [Settings] section
; ----------------------------------------

alias GetSetting {

  GetData

  return $hget(settings, $1)

}


; ----------------------------------------
; Alias: GetSite
; Description: returns a site-specific value
; Data: <SiteName> <Key>
; ----------------------------------------

alias GetSite {

  GetData

  return $hget(sites, $1 $+ . $+ $2)

}

; ----------------------------------------
; Alias: getAllSites
; Description: returns a list of all site names (based on *.name entries)
; ----------------------------------------

alias getAllSites {

  ; Set variables
  var %sites
  var %index = 1

  while ($hfind(sites, *.name, %index, w)) {

    ; Split on dot: SiteName.key
    %sites = %sites $gettok($v1, 1, 46)

    inc %index

  }

  return %sites

}

; ----------------------------------------
; Alias: isCheckBotTimer
; Description: handle the timer check for "isCheckBot"
; ----------------------------------------

alias isCheckBotTimer {

  ; Set local variable
  var %alias = isCheckBotTimer

  ; Set variables from settings
  var %intervalMin = $GetSetting(CheckInterval)

  ; Fallback
  if (!%intervalMin) {
    set %intervalMin 1
  }

  ; Has the value changed from last time
  if (%intervalMin != %lastCheckBotInterval) {

    set %lastCheckBotInterval %intervalMin

    ; Stop old timer
    .timerCheckBot off

    ; Convert to minutes
    var %intervalSec = $calc(%intervalMin * 60)

    ; Safety net
    if (%intervalSec < 60) {
      set %intervalSec 60
    }

    ; Start new timer
    timerCheckBot 0 %intervalSec isCheckBot

  }
}


; ----------------------------------------
; Alias: checkBot
; Description: Check if bot is in channel
; ----------------------------------------

alias isCheckBot {

  ; Set local variable
  var %alias = isCheckBot

  ; Set variables from settings
  var %globalBotNick = $GetSetting(BotNick)
  var %debug = $GetSetting(Debug)
  var %info = $GetSetting(Info)
  var %code = $GetSetting(Code)
  var %error = $GetSetting(Error)

  if (%debug) {
    einvite $+([,%alias,-Debug]) Entering checkBot alias - this periodically checks if the bot is in configured channels and invites if missing
  }

  ; Get all sites
  var %sitesList = $getAllSites


  if (%debug) {
    einvite $+([,%alias,-Debug]) Loaded sites list: %sitesList all site names from hash
  }

  ; Loop over all connections (multi-server support)
  if (%debug) {
    einvite $+([,%alias,-Debug]) Number of active connections: $scon(0) - looping through each
  }

  var %c = 1

  while ($scon(%c)) {

    scon %c

    if (%debug) {
      einvite $+([,%alias,-Debug]) Switched to connection %c, current network: $network
      einvite $+([,%alias,-Debug]) Checking network: $network
    }

    ; Loop through sites for this network
    var %siteIndex = 1
    var %siteCount = $numtok(%sitesList, 32)

    if (%debug) {
      einvite $+([,%alias,-Debug]) Site count for processing: %siteCount
    }

    while (%siteIndex <= %siteCount) {

      var %site = $gettok(%sitesList, %siteIndex, 32)

      if (%debug) {
        einvite $+([,%alias,-Debug]) Processing site: %site
      }

      var %siteNetwork = $GetSite(%site, network)

      if (%debug) {
        einvite $+([,%alias,-Debug]) Site network: %siteNetwork
      }

      ; Skip if site network doesn't match current connection's network (if specified)
      if (%siteNetwork && %siteNetwork != $network) {
        if (%debug) {
          einvite $+([,%alias,-Error]) Skipping %site - network mismatch $+($chr(40),%siteNetwork vs $network,$chr(41))
          einvite $+([,%alias,-Error]) Skipping site %site $+($chr(40),network mismatch: %siteNetwork vs $network,$chr(41))
        }

        inc %siteIndex

        continue

      }

      if (%debug) {
        einvite $+([,%alias,-Debug]) Processing site %site on $network
      }

      ; Set variables from site
      var %botnick = $GetSite(%site, botnick)

      if (%debug) {
        einvite $+([,%alias,-Debug]) Per-site botnick: %botnick (null if not set in INI)
        einvite $+([,%alias,-Debug]) Per-site botnick for %site: %botnick (before fallback)
      }

      ; Check what botnick to use
      if (%botnick == $null) {

        if (%debug) {
          einvite $+([,%alias,-Debug]) Site botnick null, attempting fallback to global botnick
        }

        if (%globalBotNick != $null) {

          ; Use global botnick
          %botnick = %globalBotNick

          if (%debug) {
            einvite $+([,%alias,-Debug]) Fell back to global BotNick: %botnick
          }

        } else {

          ; No botnick found
          if (%debug) {
            einvite $+([,%alias,-Debug]) No botnick available - skipping site
          }

          if (%error) {
            einvite $+([,%alias,-Error]) No botnick found for site %site and no global botnick was set!
          }

          inc %siteIndex

          continue

        }
      }

      ; Get channel list
      var %channelList = $GetSite(%site, channels)

      if (%debug) {
        einvite $+([,%alias,-Debug]) Channel list for %site : %channelList
      }

      var %channelCount = $numtok(%channelList,44)

      if (%debug) {
        einvite $+([,%alias,-Debug]) Channel count: %channelCount
      }

      var %channelIndex = 1

      ; Loop through channels for this site
      while (%channelIndex <= %channelCount) {

        ; Set local variable
        var %channel = $gettok(%channelList,%channelIndex,44)

        if (%debug) {
          einvite $+([,%alias,-Debug]) Checking channel: %channel
        }

        ; Check if YOU are in the channel
        if ($nick(%channel, $me)) {

          if (%debug) {
            einvite $+([,%alias,-Debug]) User $me is in %channel - proceeding to check bot
          }

          if (%info) {
            einvite $+([,%alias,-Info]) $me is in %channel (checking bot)
          }

          ; Check if bot is missing
          if (!$nick(%channel, %botnick)) {

            if (%info) {
              einvite $+([,%alias,-Info]) Bot %botnick not in %channel - attempting invite
            }

            if (%debug) {
              einvite $+([,%alias,-Debug]) %botnick not in %channel
            }

            ; Check if user has op (@) in the channel
            if ($left($nick(%channel, $me).pnick, 1) == @) {

              if (%code) {
                einvite $+([,%alias,-Code]) User has op in %channel - sending direct /invite %botnick %channel
              }

              quote INVITE %botnick %channel

            } else {

              if (%info) {
                einvite $+([,%alias,-Info]) User does not have op in %channel - falling back to FTP invite via isInvite
              }

              isInvite %channel

            }
          } else {

            if (%debug) {
              einvite $+([,%alias,-Debug]) Bot %botnick is already in %channel - no action needed
            }

            if (%info) {
              einvite $+([,%alias,-Info]) %botnick already in %channel
            }
          }
        } else {

          if (%debug) {
            einvite $+([,%alias,-Debug]) User $me not in %channel - skipping bot check
          }

          if (%info) {
            einvite $+([,%alias,-Info]) You are not in %channel (skipping)
          }
        }

        inc %channelIndex

      }

      inc %siteIndex

    }

    inc %c

  }

  if (%debug) {
    einvite $+([,%alias,-Debug]) Exiting: %alias alias
  }
}

; ----------------------------------------
; Function: isSynchronize
; Description: synchronize invite messages
; ----------------------------------------
alias isSynchronize {

  ; Set local variable
  var %type = isSynchronize

  ; Set variables from settings
  var %SyncMode = $GetSetting(SyncMode)
  var %info = $GetSetting(Info)
  var %debug = $GetSetting(Debug)
  var %error = $GetSetting(Error)

  ; -----------------------------
  ; Validate SyncMode
  ; -----------------------------

  if (%SyncMode != 0 && %SyncMode != 1) {

    if (%error && $network) {

      var %w = @Invite- $+ $network

      if (!$window(%w)) {
        window -en %w
      }

      echo -tq %w [isSynchronize-Error] Invalid value for SyncMode %SyncMode

    }

    return

  }

  ; -----------------------------
  ; Parse input
  ; -----------------------------

  var %origin_network = $1
  var %message = $2-

  ; Detect invite-only message
  if ($pos(%message,Unable to join #,1) && $pos(%message,(invite only),1)) {
    var %is_invite_only = 1
  } else {
    var %is_invite_only = 0
  }

  ; -----------------------------
  ; Loop connections
  ; -----------------------------
  var %i = 1

  while ($scon(%i)) {

    scon %i

    ; Skip detached contexts
    if (!$network) {

      inc %i

      continue

    }

    var %win = @Invite- $+ $network

    ; --------------------------------
    ; Origin network
    ; --------------------------------
    if ($network == %origin_network) {

      ; Create window ONLY on invite-only
      if (!$window(%win)) {
        if (%is_invite_only) {

          window -en %win

        } else {

          inc %i

          continue

        }
      }

      if (%SyncMode == 1) {
        echo -tq %win $+([,%origin_network,]) %message
      } else {
        echo -tq %win %message
      }
    }

    ; --------------------------------
    ; Other networks (sync only)
    ; --------------------------------
    elseif (%SyncMode == 1) {

      ; Never create window unless invite-only
      if (!$window(%win)) {

        if (%is_invite_only) {

          window -en %win

        } else {

          inc %i

          continue

        }
      }

      echo -tq %win $+([,%origin_network,]) %message

    }

    inc %i

  }
}

; ----------------------------------------
; Function: isInvite
; Description: Main handler for invite events.
; ----------------------------------------
alias isInvite {

  ; Set variables from settings
  var %debug = $GetSetting(Debug)
  var %error = $GetSetting(Error)

  ; Set variables
  var %type = isInvite

  ; Set channel
  if ($1) {
    var %channel = $1
  } else {
    var %channel = $strip($gettok($rawmsg, 4, 32))
  }

  ; Check if channel is empty
  if (%channel == "") {
    if (%error) {
      einvite $+([,%type,-Error]) Could not parse channel from RAW 473: $rawmsg
    }

    ; Exit
    return

  }

  ; Normalize channel
  var %channel = $lower(%channel)

  if (%debug) {
    einvite $+([,%type,-Debug]) Parsed channel: %channel
  }

  ; Get site information for the current channel
  var %siteResult = $isSite(%channel)

  ; Extract the main result (1 = known site, 0 = unknown site)
  var %result = $gettok(%siteResult,1,32)

  ; Check if site not found
  if (%result == 0) {
    if (%debug) {
      einvite $+([,%type,-Debug]) Unknown channel: cannot resolve site %channel (RAW: $rawmsg )
    }

    ; Exit
    return
  } else {

    ; Extract site identifier and site name
    var %site = $gettok(%siteResult,2,32)
    var %name = $gettok(%siteResult,3,32)

  }

  if (%debug) {
    einvite $+([,%type,-Debug]) Site resolved: %site for channel %channel
  }

  ; Check if timer exists
  if ($isTimer(%site)) {
    if (%debug) {
      einvite $+([,%type,-Debug]) Cooldown active for %site, skipping FTP trigger
    }

    ; Exit
    return

  }

  ; Run FTP sequence
  isFTP %site %channel

}

; ----------------------------------------
; Function: isSite
; Description: Check if a channel belongs to a known site
; Returns: 1 = known site, 0 = unknown site
; ----------------------------------------
alias isSite {

  ; Set local variables
  var %channel = $1
  var %type = isSite
  var %debug = $GetSetting(Debug)

  if (%debug) {
    einvite $+([,%type,-Debug]) Checking channel: %channel
  }

  ; Get all sites
  var %sitesList = $getAllSites
  var %siteCount = $numtok(%sitesList, 32)
  var %i = 1

  ; Loop through all site sections
  while (%i <= %siteCount) {

    ; Set local variables from site
    var %site = $gettok(%sitesList, %i, 32)
    var %channels = $GetSite(%site, channels)
    var %name = $GetSite(%site, name)
    var %ignore_entire = $GetSite(%site, ignore_entire)
    var %siteNetwork = $GetSite(%site, network)

    ; Skip if site network doesn't match current (or if no network, assume ok)
    if (%siteNetwork && %siteNetwork != $network) {
      inc %i | continue
    }

    ; Skip if site does not contain this channel
    if (!$istok(%channels, %channel, 44)) {
      inc %i | continue
    }

    ; Check if entire site should be ignored
    if (%ignore_entire == 1) {
      if (%debug) {
        einvite $+([,%type,-Debug]) Site %site is entirely ignored
      }

      return 0

    }

    ; No per-channel ignore check - removed to allow invites for configured channels
    if (%debug) {
      einvite $+([,%type,-Debug]) Site resolved: %site ( %name ) for channel %channel
    }

    return 1 %site %name

  }

  if (%debug) {
    einvite $+([,%type,-Debug]) Unknown channel: %channel
  }

  return 0

}

; ----------------------------------------
; Function: isTimer
; Description: Per-site cooldown system using hash table.
; ----------------------------------------

alias isTimer {

  ; Set local variables
  var %site = $1
  var %type = isTimer
  var %debug = $GetSetting(Debug)

  ; Initialize hash table if it doesn't exist
  if (!$hget(inviteTimers)) {

    ; Create hash table
    hmake inviteTimers 10

  }

  ; Get last timestamp for this site
  var %lastTime = $hget(inviteTimers, %site)

  ; Calculate time passed since last action for site
  var %timePassed = $calc($ctime - %lastTime)

  ; Check if cooldown is still active
  if (%lastTime && %timePassed < 60) {
    if (%debug) {
      einvite $+([,%type,-Debug]) $+(%site) timer is active: $calc(60 - %timePassed) seconds remaining
    }

    ; Timer active
    return 1

  }
  ; Update timestamp for site
  hadd inviteTimers %site $ctime

  if (%debug) {
    einvite $+([,%type,-Debug]) No active timer for %site (cooldown passed)
  }

  ; Timer inactive
  return 0

}

; ----------------------------------------
; Function: isFTP
; Description: Runs FlashFXP against relevant site
; ----------------------------------------

alias isFTP {

  ; Set local variables
  var %site = $1
  var %channel = $2
  var %alias = isFTP

  ; Get settings variables
  var %debug = $GetSetting(Debug)
  var %info = $GetSetting(Info)
  var %code = $GetSetting(Code)
  var %error = $GetSetting(Error)

  if (%debug) {
    einvite $+([,%alias,-Debug]) Entering isFTP, site: %site, channel: %channel
  }

  var %flashfxp_path = $GetSetting(FlashFXPPath)

  if (%code) {
    einvite $+([,%alias,-Code]) flashfxp_path: %flashfxp_path
  }

  if (%info) {
    einvite $+([,%alias,-Info]) Triggering FlashFXP for %site / %channel
  }

  ; Get ftpsites and ignores
  var %ftpsites = $GetSite(%site, ftpsites)

  if (%code) {
    einvite $+([,%alias,-Code]) ftpsites: %ftpsites
  }

  var %ftpsites_ignore = $GetSite(%site, ftpsites_ignore)

  if (%code) {
    einvite $+([,%alias,-Code]) ftpsites_ignore: %ftpsites_ignore
  }

  ; Remove ignored from ftpsites (comma-separated)
  if (%ftpsites_ignore) {

    if (%debug) {
      einvite $+([,%alias,-Debug]) Removing ignores
    }

    var %ignoreCount = $numtok(%ftpsites_ignore, 44)

    if (%debug) {
      einvite $+([,%alias,-Debug]) ignoreCount: %ignoreCount
    }

    var %ig = 1

    while (%ig <= %ignoreCount) {

      var %ign = $gettok(%ftpsites_ignore, %ig, 44)

      if (%code) {
        einvite $+([,%alias,-Code]) Removing: %ign
      }

      %ftpsites = $remtok(%ftpsites, %ign, 1, 44)

      if (%code) {
        einvite $+([,%alias,-Code]) ftpsites after remove: %ftpsites
      }

      inc %ig

    }
  }

  ; Check if any ftpsites left
  var %remainingCount = $numtok(%ftpsites, 44)

  if (%code) {
    einvite $+([,%alias,-Code]) remaining ftpsites count: %remainingCount
  }

  if (!%remainingCount) {

    if (%code) {
      einvite $+([,%alias,-Code]) No valid ftpsites
    }

    if (%error) {
      einvite $+([,%alias,-Error]) No valid ftpsites available for %site (all ignored or none defined)
    }

    return

  }

  ; Pick a random ftpsite
  var %ftpCount = $numtok(%ftpsites, 44)

  if (%code) {
    einvite $+([,%alias,-Code]) ftpCount: %ftpCount
  }

  var %randIndex = $rand(1, %ftpCount)

  if (%code) {
    einvite $+([,%alias,-Code]) randIndex: %randIndex
  }

  var %picked = $gettok(%ftpsites, %randIndex, 44)

  if (%code) {
    einvite $+([,%alias,-Code]) picked: %picked
  }

  if (%debug) {
    einvite $+([,%alias,-Debug]) Selected ftpsite for %site: %picked ( from available: %ftpsites )
  }

  ; Set FlashFXP (site name/path)
  var %ftpSite = $+(Sites\, %site, \,%picked)

  if (%code) {
    einvite $+([,%alias,-Code]) ftpSite: %ftpSite
  }

  ; Validate executable
  if (!$file(%flashfxp_path)) {

    if (%debug) {
      einvite $+([,%alias,-Debug]) FlashFXP not found
    }

    if (%error) {
      einvite $+([,%alias,-Error]) FlashFXP not found at: %flashfxp_path
    }

    ; Exit
    return


  }

  if (%code) {
    einvite $+([,%alias,-Code]) Running command: $qt(%flashfxp_path) -raw="SITE WHO" -tray -quit $qt(%ftpSite)
  }

  ; Launch application
  run $qt(%flashfxp_path) -raw="SITE WHO" -tray -quit $qt(%ftpSite)

  if (%info && %picked != $null) {
    einvite $+([,%alias,-Info]) FlashFXP started for %site on %channel (using %picked)
  }

  if (%debug) {
    einvite $+([,%alias,-Debug]) Exiting: %alias
  }
}