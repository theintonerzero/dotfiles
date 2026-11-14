# tests/test_firefox.sh: firefox's policies, which both oses set from the one file: what's hardened, and
# what's left working on purpose
# shellcheck shell=bash
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
f=$REPO/shared/firefox-policies.json
# policy <label> <jq filter>: the filter holds of the policies
policy() { jq -e ".policies | $2" "$f" >/dev/null || fail "firefox policy: $1"; }

policy "strict tracking protection" '.EnableTrackingProtection == {Value: true, Category: "strict"}'
policy "no cookies policy, which would turn strict into custom" 'has("Cookies") | not'
policy "encrypted dns, falling back to the system's" '.DNSOverHTTPS == {Enabled: true, Fallback: true, Locked: false}'
policy "no dns prefetch" '.NetworkPrediction == false'
policy "no search suggestions" '.SearchSuggestEnabled == false'
policy "no firefox suggest" '.FirefoxSuggest == {WebSuggestions: false, SponsoredSuggestions: false, OnlineEnabled: false, Locked: false}'
policy "duckduckgo" '.SearchEngines == {Default: "DuckDuckGo"}'
policy "no notification prompts, and a site can still be allowed" '.Permissions.Notifications == {BlockNewRequests: true, Locked: false}'
policy "no location prompts, and a site can still be allowed" '.Permissions.Location == {BlockNewRequests: true, Locked: false}'
policy "camera and microphone can still be asked for" '(.Permissions | has("Camera") or has("Microphone")) | not'
policy "no password manager" '.PasswordManagerEnabled == false'
policy "no saved addresses or cards" '.AutofillAddressEnabled == false and .AutofillCreditCardEnabled == false'
policy "no experiments or promotions" '.DisableRemoteImprovements == true and .UserMessaging.FirefoxLabs == false
  and .UserMessaging.UrlbarInterventions == false and .UserMessaging.MoreFromMozilla == false'
policy "global privacy control" '.Preferences["privacy.globalprivacycontrol.enabled"] == {Value: true, Status: "locked"}'
policy "other sites see only the site you came from" '.Preferences["network.http.referer.XOriginTrimmingPolicy"] == {Value: 2, Status: "default", Type: "number"}'
policy "calls keep your local addresses to themselves" '.Preferences["media.peerconnection.ice.default_address_only"].Value == true'
policy "lookalike names in their raw form" '.Preferences["network.IDN_show_punycode"].Value == true'
policy "no scripts in pdfs" '.Preferences["pdfjs.enableScripting"].Value == false'
policy "nothing fetched before you click" '.Preferences["network.prefetch-next"].Value == false
  and .Preferences["browser.urlbar.speculativeConnect.enabled"].Value == false
  and .Preferences["browser.places.speculativeConnect.enabled"].Value == false'

# ublock origin's lists: its own defaults, your filters, and the two additions
lists='.["3rdparty"].Extensions["uBlock0@raymondhill.net"].toOverwrite.filterLists'
for token in user-filters ublock-filters ublock-badware ublock-privacy ublock-unbreak ublock-quick-fixes \
  easylist easyprivacy urlhaus-1 plowe-0 adguard-spyware-url fanboy-cookiemonster ublock-cookies-easylist; do
  policy "ublock list $token" "$lists | index(\"$token\") != null"
done
policy "ublock still installed" '.ExtensionSettings["uBlock0@raymondhill.net"].installation_mode == "normal_installed"'

# what was there stays
policy "https only" '.HttpsOnlyMode == "enabled"'
policy "no telemetry or studies" '.DisableTelemetry == true and .DisableFirefoxStudies == true'
policy "ai features off" '.AIControls.Default.Value == "blocked"'

# left working on purpose: the last session, webgl, drm video, dark mode and your time zone
policy "the last session is restored" '.Homepage.StartPage == "previous-session"'
policy "nothing cleared when firefox quits" '(has("SanitizeOnShutdown") or has("ClearOnShutdown")) | not'
policy "no heavy fingerprinting resistance, webgl or drm switched off" '[.Preferences | keys[]
  | select(test("resistFingerprinting|^webgl\\.|^media\\.eme\\.|^media\\.gmp"))] == []'
policy "sync stays" '(has("DisableFirefoxAccounts") or has("DisableAccounts")) | not'
policy "safe browsing stays" '[.Preferences | keys[] | select(test("safebrowsing"))] == []'

# every pref is one the Preferences policy takes: firefox drops any other without a word
allowed='^(accessibility\.|alerts\.|app\.update\.|browser\.|datareporting\.policy\.|devtools\.|dom\.|extensions\.|geo\.|gfx\.|intl\.|layers\.|layout\.|media\.|network\.|pdfjs\.|places\.|pref\.|print\.|signon\.|spellchecker\.|ui\.|widget\.|privacy\.globalprivacycontrol\.enabled$|privacy\.fingerprintingProtection$)'
eq "prefs the policy won't take" "" "$(jq -r '.policies.Preferences | keys[]' "$f" | grep -vE "$allowed" || true)"
