# Ready to publish for MoSahil147/Football-Notch-for-MacBook v0.1.0.
# This file does NOT live here when actually published: copy it into the
# Casks/ folder of a separate GitHub repo named homebrew-football-notch
# (Homebrew's tap-naming convention), then push it there. Users then run
# either:
#   brew install --cask MoSahil147/football-notch/football-notch
# or:
#   brew tap MoSahil147/football-notch
#   brew install --cask football-notch
#
# For a future version bump: re-run Distribution/build_release.sh, update
# `version` below, and replace `sha256` with the new zip's
# `shasum -a 256` output.
cask "football-notch" do
  version "0.1.0"
  sha256 "9e184f29d4a179428334f68cd875e77a50bb112557af691e6e3f1304b8d9b7ee"

  url "https://github.com/MoSahil147/Football-Notch-for-MacBook/releases/download/v#{version}/FootballNotch.zip"
  name "Football Notch"
  desc "Live football scores in your MacBook's notch"
  homepage "https://github.com/MoSahil147/Football-Notch-for-MacBook"

  app "FootballNotch.app"

  # The release build is ad-hoc signed, not signed with a paid Apple
  # Developer ID (see Distribution/build_release.sh) — without this,
  # Gatekeeper would show an "unidentified developer" warning the first
  # time someone opens the app. Stripping the quarantine attribute here
  # runs automatically as part of `brew install --cask`, before the user
  # ever opens the app themselves, so they never see that warning at all.
  postflight do
    system_command "/usr/bin/xattr",
                    args: ["-cr", "#{appdir}/FootballNotch.app"]
  end
end
