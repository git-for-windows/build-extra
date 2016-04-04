@echo off
@echo Building IDP documentation:
lua main.lua
@echo Building HTMLHelp:
"%ProgramFiles%\HTML Help Workshop\hhc.exe" idp.hhp
@echo Done.
@pause
@echo on