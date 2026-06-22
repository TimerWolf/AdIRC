;######################################
; AdIRC: SiteInvite-Initialization    #
; Revision: 1                         #
; Date created: 05/09/2026            #
; Date last modified: 05/09/2026      #
; Author: Whiskey                     #
; #####################################

on *:START:{

  ; ----------------------------------------
  ; Load Script
  ; ----------------------------------------

  var %base = $scriptdir
  load -rs $qt(%base $+ SiteInvite-Code.mrc)
  load -rs $qt(%base $+ siteInvite-Interface.mrc)

}