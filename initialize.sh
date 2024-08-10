#!/bin/bash
# repo-add -n x86_64/StratOS-repo.db.tar.gz x86_64/*.pkg.tar.zst**
# Check cassava/repoctl README for tips
repoctl conf new x86_64/StratOS-repo.db.tar.zst
repoctl reset