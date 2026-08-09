; DEPRECATED as a compile entrypoint.
; The unique source of truth is installer/folio_setup.iss.template
; Build with:
;   .\tool\windows\build_installer.ps1 -RepoRoot . -SourceDir build\windows\x64\runner\Release -OutputDir Output
; or:
;   .\builld_all.ps1  (menu → installer)
;
; Kept so older docs/bookmarks still point somewhere useful.
#error "Do not compile installer.iss directly. Use tool/windows/build_installer.ps1 (see installer/folio_setup.iss.template)."
