#!/bin/bash
repo-add -R x86_64/stratos.db.tar.gz x86_64/*.pkg.tar.zst
# Check cassava/repoctl README for tips
# rm -rf x86_64/StratOS-repo**
# repoctl conf new x86_64/StratOS-repo.db.tar.zst
# repoctl reset
