# Maintainer: Jguer <pkgbuilds at jguer.space>
pkgname=yay-bin
pkgver=12.4.2
pkgrel=1
pkgdesc="Yet another yogurt. Pacman wrapper and AUR helper written in go. Pre-compiled."
arch=('x86_64' 'aarch64' 'armv7h')
url="https://github.com/Jguer/yay"
license=('GPL-3.0-or-later')
depends=(
  'pacman>6.1'
  'git'
)
optdepends=(
  'sudo: privilege elevation'
  'doas: privilege elevation'
)
provides=('yay')
conflicts=('yay')

source_x86_64=("https://github.com/Jguer/yay/releases/download/v${pkgver}/${pkgname/-bin/}_${pkgver}_x86_64.tar.gz")
source_aarch64=("https://github.com/Jguer/yay/releases/download/v${pkgver}/${pkgname/-bin/}_${pkgver}_aarch64.tar.gz")
source_armv7h=("https://github.com/Jguer/yay/releases/download/v${pkgver}/${pkgname/-bin/}_${pkgver}_armv7h.tar.gz")

sha256sums_x86_64=('1ad3e5dbc410edc668eb9062bb6e56b90da818780581f06aa79dd696aa0b5ceb')
sha256sums_aarch64=('cc4b7db8937e9dc5d0a02e0900928c4ab1c9e8837c4fd4c78856e67ba32c1e0f')
sha256sums_armv7h=('daa4e82dd03146d1b1501897ff9128beca280d42c8f17fccc90e51723321e58e')

package() {
  _output="${srcdir}/${pkgname/-bin/}_${pkgver}_${CARCH}"
  install -Dm755 "${_output}/${pkgname/-bin/}" "${pkgdir}/usr/bin/${pkgname/-bin/}"
  install -Dm644 "${_output}/yay.8" "${pkgdir}/usr/share/man/man8/yay.8"

  # Shell autocompletion script
  install -Dm644 "${_output}/bash" "${pkgdir}/usr/share/bash-completion/completions/yay"
  install -Dm644 "${_output}/zsh" "${pkgdir}/usr/share/zsh/site-functions/_yay"
  install -Dm644 "${_output}/fish" "${pkgdir}/usr/share/fish/vendor_completions.d/yay.fish"

  LANGS="ca cs de en es eu fr_FR he id it_IT ja ko pl_PL pt_BR pt ru_RU ru sv tr uk zh_CN zh_TW"
  for lang in ${LANGS}; do
    install -Dm644 "${_output}/${lang}.mo" "${pkgdir}/usr/share/locale/${lang}/LC_MESSAGES/yay.mo"
  done
}
