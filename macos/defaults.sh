#!/usr/bin/env bash

echo "Applying macOS defaults..."

# show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# show status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true

# faster key repeat
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# automatically hide the dock
defaults write com.apple.dock autohide -bool true

# reduce dock animation delay
defaults write com.apple.dock autohide-delay -float 0

# show battery percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

# restart affected apps
killall Finder
killall Dock

echo "macOS defaults applied."
