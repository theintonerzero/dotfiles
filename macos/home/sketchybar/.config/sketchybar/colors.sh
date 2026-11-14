# colors.sh: the bar's colours and font, named as the prompt's kanagawa dragon palette names them, and the
# three ways a pill is dressed; the config and every plugin read this
# shellcheck shell=bash
# shellcheck disable=SC2034 # read by whatever sources this

SURFACE=0xff282727
TEXT=0xffc5c9c5
BRANCH=0xffa6a69c
ACCENT=0xff7a8382
ON_ACCENT=0xff0d0c0c
DIM=0xff8c8882
OK=0xff87a987
ERR=0xffc4746e
CLEAR=0x00000000
FONT="JetBrainsMono Nerd Font"

# plain: nothing to say but the fact; alert: bad news; good: on the charger
PLAIN=("background.color=$SURFACE" "icon.color=$BRANCH" "label.color=$TEXT" "label.font=$FONT:Regular:13.0")
ALERT=("background.color=$ERR" "icon.color=$ON_ACCENT" "label.color=$ON_ACCENT" "label.font=$FONT:Bold:13.0")
GOOD=("background.color=$SURFACE" "icon.color=$OK" "label.color=$OK" "label.font=$FONT:Regular:13.0")
