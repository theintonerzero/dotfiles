# a login shell reads this after /etc/zprofile, whose path_helper has just put apple's folders ahead of
# everything ~/.zshenv set; reading .zshenv again puts PATH back in its order, so homebrew's git, bash and
# python come before apple's
source ~/.zshenv
