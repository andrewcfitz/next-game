#!/usr/bin/env bash
# Writes Casks/next-game.rb for a release. Usage: Scripts/update-cask.sh 1.2.0 <sha256>
set -euo pipefail

version="${1:?version}"
sha256="${2:?sha256}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$repo_root/Casks"
cat > "$repo_root/Casks/next-game.rb" <<CASK
cask "next-game" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/andrewcfitz/next-game/releases/download/v#{version}/NextGame-#{version}.zip"
  name "Next Game"
  desc "Menu bar app and widget counting down to your next campground stay"
  homepage "https://github.com/andrewcfitz/next-game"

  depends_on macos: ">= :sequoia"

  app "NextGame.app"

  uninstall quit: "biz.fitz.NextGame"

  zap trash: [
    "~/Library/Containers/biz.fitz.NextGame",
    "~/Library/Containers/biz.fitz.NextGame.Widget",
    "~/Library/Group Containers/8353VT99LA.biz.fitz.NextGame",
  ]
end
CASK
echo "Wrote Casks/next-game.rb for $version"
