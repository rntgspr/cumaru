class Cumaru < Formula
  desc "Context-oriented knowledge framework for AI-assisted work"
  homepage "https://github.com/rntgspr/cumaru"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/rntgspr/cumaru/releases/download/0.10.3/cumaru-aarch64-apple-darwin", using: :nounzip
      sha256 "84ad504159200a625a6430bbe9456b9eb707d0284e791c7ccbb96fa880e75be0"
    end
    on_intel do
      url "https://github.com/rntgspr/cumaru/releases/download/0.10.3/cumaru-x86_64-apple-darwin", using: :nounzip
      sha256 "42475f5109ceabe9a0c8dafcfa948be1cc1743a32bee824b27c724b40986273d"
    end
  end

  on_linux do
    depends_on "curl"
    depends_on "git"

    on_arm do
      url "https://github.com/rntgspr/cumaru/releases/download/0.10.3/cumaru-aarch64-unknown-linux-musl", using: :nounzip
      sha256 "2e157c5c47fd567dabbbdad75273939211da10108d148ab975766962e1ffba2c"
    end
    on_intel do
      url "https://github.com/rntgspr/cumaru/releases/download/0.10.3/cumaru-x86_64-unknown-linux-musl", using: :nounzip
      sha256 "6aeb84d207d4729243f0893248e8773374b42ad6c80ceb51101db827c9c21509"
    end
  end

  # Install only the verified executable and block the unmanaged global installer.
  def install
    if OS.linux? && Hardware::CPU.arm?
      features = File.read("/proc/cpuinfo").scan(/^Features\s*:\s*(.*)$/).flatten
      if features.empty? || features.any? { |flags| (flags.split & %w[fphp asimdhp]).size != 2 }
        odie "Cumaru's Linux ARM64 release requires FP16 (fphp and asimdhp)."
      end
    end

    libexec.install Dir["cumaru-*"].fetch(0) => "cumaru"
    chmod 0755, libexec/"cumaru"
    (bin/"cumaru").write <<~EOS
      #!/bin/bash
      # Homebrew owns this binary; never run the unmanaged /usr/local/bin installer.
      command="$1"
      [[ "$command" == -- ]] && command="$2"
      if [[ "$command" == upgrade && " $* " != *" --check "* && " $* " != *" --help "* && " $* " != *" -h "* ]]; then
        echo "cumaru upgrade: managed by Homebrew; run brew upgrade rntgspr/tap/cumaru" >&2
        exit 1
      fi
      exec "#{libexec}/cumaru" "$@"
    EOS
  end

  # Explain package ownership and the optional user-owned model cache.
  def caveats
    <<~EOS
      Use brew upgrade rntgspr/tap/cumaru for this installation.
      Bare cumaru upgrade is blocked; cumaru upgrade --check remains read-only.
      Models are optional and installed only by an explicit cumaru model push.
      Brew uninstall leaves ~/.cumaru models and project knowledge untouched.
    EOS
  end

  # Exercise offline ranking and ensure self-upgrade cannot escape the managed keg.
  test do
    assert_equal "cumaru #{version}\n", shell_output("#{bin}/cumaru --version")
    assert_match "context", shell_output("#{bin}/cumaru help")
    assert_match "managed by Homebrew", shell_output("#{bin}/cumaru upgrade 2>&1", 1)

    (testpath/"home").mkpath
    (testpath/".cumaru/eggs.md").write "# Egg recipes\n\nBoil eggs for six minutes.\n"
    with_env(HOME: (testpath/"home").to_s) do
      output = shell_output("#{bin}/cumaru context 'look for egg recipes' 2>/dev/null")
      assert_match(/^eggs\.md\t\d+\.\d{2}\n$/, output)
      refute_path_exists testpath/"home/.cumaru"
    end
  end
end
