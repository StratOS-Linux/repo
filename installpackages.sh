#!/bin/bash
echo "Enter the package you want to add to the repo : "
read packagename
aur sync --repo LUGOS-repo --root x86_64 $packagename
echo "Updating Database....."
repo-add -n x86_64/LUGOS-repo.db.tar.gz x86_64/*.pkg.tar.zst
rm x86_64/LUGOS-repo.db x86_64/LUGOS-repo.files
mv x86_64/LUGOS-repo.db.tar.gz x86_64/LUGOS-repo.db
mv x86_64/LUGOS-repo.files.tar.gz x86_64/LUGOS-repo.files
echo "Pushing files to repo...."
git add .
git commit -m "Added $packagename to the repo"
git push
