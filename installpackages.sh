#!/bin/bash
echo "Enter the package you want to add to the repo : "
read packagename
aur sync --repo StratOS-repo --root x86_64 $packagename
echo "Updating Database....."
repo-add -n x86_64/StratOS-repo.db.tar.gz x86_64/*.pkg.tar.zst
echo "Pushing files to repo...."
git add .
git commit -m "Added $packagename to the repo"
git push
