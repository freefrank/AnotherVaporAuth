; Packs a Flutter Windows Release *folder* into a single portable .exe.
;
; Flutter's Windows output is a directory — ava.exe is only a launcher and does
; nothing without flutter_windows.dll and data\ beside it. Shipping "one file
; you can drop anywhere" therefore needs a packer that unpacks at runtime.
;
; This replaces Enigma Virtual Box, which was closed-source, downloaded fresh
; from an unversioned vendor URL on every build, published no digest to pin,
; and failed the release twice (2026-07-30 and 2026-08-08) when that download
; came back truncated. NSIS is open source, ships preinstalled on the GitHub
; Windows runners, and this script lives in the repo where it can be reviewed.
;
; Build:
;   makensis /DSRCDIR=<Release dir> /DOUTFILE=<out.exe> /DAPPVER=<x.y.z> portable.nsi
;
; $PLUGINSDIR is NSIS's own scratch directory: created by InitPluginsDir, and
; **deleted automatically when this process exits**. Combined with ExecWait —
; which keeps the outer process alive for exactly as long as the app runs —
; that gives extract, run, clean up, with no bookkeeping of our own.
;
; NOT usable for the installer (tool/pack_portable.ps1, -NoTempMap): that one
; needs the running process image to *be* the outer exe, because engine.dart
; copies Platform.resolvedExecutable to produce uninstall.exe. Here the running
; image is the extracted copy, which is fine — the portable app never
; reproduces itself.

Unicode true
ManifestDPIAware true

!ifndef SRCDIR
  !error "SRCDIR is required: /DSRCDIR=<path to the Release folder>"
!endif
!ifndef OUTFILE
  !error "OUTFILE is required: /DOUTFILE=<path to the exe to write>"
!endif
!ifndef APPVER
  !define APPVER "0.0.0"
!endif

Name "AVA"
OutFile "${OUTFILE}"
; Portable means portable: no elevation prompt, and nothing written outside
; the user's own profile. Account data still goes to the per-user data
; directory, exactly as in the installed build.
RequestExecutionLevel user
SilentInstall silent
SetCompressor /SOLID lzma

!ifdef ICONFILE
  Icon "${ICONFILE}"
!endif

VIProductVersion "${APPVER}.0"
VIAddVersionKey "ProductName" "AVA"
VIAddVersionKey "FileDescription" "AVA — Steam authenticator (portable)"
VIAddVersionKey "FileVersion" "${APPVER}"
VIAddVersionKey "ProductVersion" "${APPVER}"
VIAddVersionKey "LegalCopyright" "MIT licensed. Community project, unaffiliated with Valve."

!include "FileFunc.nsh"

Section
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\ava"
  File /r "${SRCDIR}\*.*"

  ; Forward whatever the user passed, so the packed exe behaves like the
  ; unpacked one rather than silently dropping arguments.
  ${GetParameters} $R0

  ; ExecWait, not Exec: returning immediately would tear down $PLUGINSDIR out
  ; from under the app that is still reading its own DLLs out of it.
  ExecWait '"$PLUGINSDIR\ava\ava.exe" $R0' $R1
  SetErrorLevel $R1
SectionEnd
