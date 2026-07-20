# Distribution/Formula/football-notch.rb
cask "football-notch" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_OF_RELEASE_ZIP"

  url "https://github.com/<github-username>/homebrew-football-notch/releases/download/v#{version}/FootballNotch.zip"
  name "Football Notch"
  desc "Live football scores in your MacBook's notch"
  homepage "https://github.com/<github-username>/Dynamic-Island"

  app "FootballNotch.app"
end
