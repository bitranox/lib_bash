# Changelog

## 1.0.0 (2025-08-31)

### Changed
- fix(changelog): convert literal \n to real newlines; print new changelog sections with actual line breaks
- move etkserver to proxmox02
- release: v1.1.9
- release(flow): auto fast-forward when behind; correct behind/ahead detection
- release: v1.1.8
- release: v1.1.7
- release: v1.1.6
- release: v1.1.5
- release: v1.1.4
- release: v1.1.3
- release: v1.1.1
- release: v1.0.13
- release: v1.0.12
- release: v1.0.11
- release: v1.0.10 — Release flow: changelog committed to master before tag
- Makefile: commit CHANGELOG on master before tagging; remove release branch step
- Makefile: use .ONESHELL so interactive release runs in a single shell
- release: v1.0.8 — Release: include tag notes and robust changelog extraction
- Makefile: include release notes in tag; robust awk matching for changelog section
- Makefile: consolidate to single interactive 'release' target
- Makefile: use explicit SHA for gh release create; remove --target on edit
- docs: add 1.0.6 entry for ssh-askpass fallback fix
- lib_bash: tolerate missing ssh-askpass in _set_askpass; avoid ERR noise under strict mode
- chore(changelog): add 1.0.5 section
- feat(makefile): add ALLOW_EXISTING_TAG=1 support; require gh for release notes; tidy formatting
- chore(changelog): add 1.0.4 section
- chore(makefile): remove release-notes target and tidy PHONY/comment formatting
- chore(makefile): remove release-notes target; AGENTS.md: reflect single release flow
- fix(makefile): single-line tag message using double -m to avoid missing separator
- feat(makefile): require gh and create/update release notes within make release; simplify release-notes to use gh only
- fix(makefile): rewrite release-notes target cleanly
- fix(makefile): proper multiline recipe for release-notes target
- feat(makefile): add release-notes target to create/update GitHub Release notes
- chore(makefile): prefer GH_TOKEN/GITHUB_TOKEN for release
- chore(changelog): add 1.0.3 section
- release: 1.0.0


