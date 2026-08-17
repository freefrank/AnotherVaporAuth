; Packs the installer app (installer/) into the single setup.exe users download.
;
; This replaces Enigma Virtual Box, which was closed source, downloaded fresh
; from an unversioned vendor URL on every build, published no digest to pin
; against, and broke the release three times when that download came back
; truncated (2026-07-30, 2026-08-08, 2026-08-17). The third one failed twice
; more on re-run while the same URL served a perfectly good 7.9 MB binary to
; a developer machine seconds later — the runner's egress could not fetch it,
; so retrying was never going to help.
;
; The installer looks and behaves exactly as before. The one thing Enigma did
; that a self-extractor cannot is keep the running process image *identical
; to* the outer exe, which engine.dart relied on in five places: mode
; detection, install-dir discovery, staged-copy detection, and the two spots
; that reproduce the program by copying its own image (uninstall.exe, and the
; %TEMP% cleanup stage). Rather than give that up, the path is passed in:
; --self=$EXEPATH, adopted by InstallEngine.adoptSelfImage before anything
; reads it. So uninstall.exe is still a byte-for-byte copy of setup.exe, and
; running it still re-enters this same wrapper.
;
; Build:
;   makensis /DSRCDIR=<installer Release dir> /DOUTFILE=<out.exe>
;            /DAPPVER=<x.y.z> [/DICONFILE=<app.ico>] setup.nsi
;
; $PLUGINSDIR is NSIS's own scratch directory: created by InitPluginsDir and
; deleted automatically when this process exits. ExecWait holds the outer
; process open for exactly as long as the installer runs, so the app never
; has its own DLLs pulled out from under it.

Unicode true
ManifestDPIAware true

!ifndef SRCDIR
  !error "SRCDIR is required: /DSRCDIR=<path to the installer Release folder>"
!endif
!ifndef OUTFILE
  !error "OUTFILE is required: /DOUTFILE=<path to the exe to write>"
!endif
!ifndef APPVER
  !define APPVER "0.0.0"
!endif

Name "AVA Setup"
OutFile "${OUTFILE}"
; AVA installs under %LOCALAPPDATA%\Programs and registers uninstall in HKCU,
; so it needs no elevation — and asking for it would be a new, scarier prompt
; than the one users see today.
RequestExecutionLevel user
SilentInstall silent
SetCompressor /SOLID lzma

!ifdef ICONFILE
  Icon "${ICONFILE}"
!endif

VIProductVersion "${APPVER}.0"
VIAddVersionKey "ProductName" "AVA"
VIAddVersionKey "FileDescription" "AVA — Steam authenticator (setup)"
VIAddVersionKey "FileVersion" "${APPVER}"
VIAddVersionKey "ProductVersion" "${APPVER}"
VIAddVersionKey "LegalCopyright" "MIT licensed. Community project, unaffiliated with Valve."

!include "FileFunc.nsh"

Section
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\setup"
  File /r "${SRCDIR}\*.*"

  ; Forward the user's own arguments (--auto, --uninstall) unchanged, and
  ; prepend the outer path. $EXEPATH is this exe wherever it currently sits:
  ; setup.exe in Downloads, uninstall.exe in the install folder, or the
  ; staged copy in %TEMP% — each of which the app has to tell apart.
  ${GetParameters} $R0

  ExecWait '"$PLUGINSDIR\setup\ava_installer.exe" "--self=$EXEPATH" $R0' $R1
  SetErrorLevel $R1
SectionEnd
