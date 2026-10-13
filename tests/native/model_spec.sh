Include tests/native/helpers.sh

Describe 'native model activation and release'
  BeforeEach 'native_setup'
  AfterEach 'native_cleanup'

  It 'releases an absent cache without writes or network access'
    When call cli model release
    The status should equal 0
    The output should include 'no model enabled'
    The error should be blank
    The path "$HOME/.cumaru" should not be exist
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'retains cached artifacts and restores offline lightweight ranking after release'
    mkdir -p "$HOME/.cumaru/bge-micro-v2" "$PROJECT/.cumaru"
    printf 'retained weights\n' > "$HOME/.cumaru/bge-micro-v2/model.safetensors"
    printf 'retained manifest\n' > "$HOME/.cumaru/bge-micro-v2/manifest.json"
    printf 'Egg recipes describe cooking eggs in butter.\n' > "$PROJECT/.cumaru/eggs.md"
    cli model release >/dev/null
    cli model release >/dev/null
    before=$(snapshot)
    When call cli context 'egg recipes'
    The status should equal 0
    The output should include 'eggs.md'
    The error should include 'backend=lightweight'
    The contents of file "$HOME/.cumaru/bge-micro-v2/model.safetensors" should equal 'retained weights'
    The contents of file "$HOME/.cumaru/bge-micro-v2/manifest.json" should equal 'retained manifest'
    The path "$HOME/.cumaru/bge-micro-v2/.released" should be file
    The value "$(snapshot)" should equal "$before"
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'refuses a symlinked release marker without changing unrelated content'
    mkdir -p "$HOME/.cumaru/bge-micro-v2"
    printf 'keep\n' > "$HOME/unrelated.txt"
    ln -s "$HOME/unrelated.txt" "$HOME/.cumaru/bge-micro-v2/.released"
    When call cli model release
    The status should equal 1
    The output should be blank
    The error should include 'invalid model release marker'
    The contents of file "$HOME/unrelated.txt" should equal keep
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'rejects unsupported pull names before any download'
    When call cli model pull unknown
    The status should equal 1
    The output should be blank
    The error should include 'unsupported model name'
    The path "$HOME/.cumaru" should not be exist
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'keeps a damaged package released when pull verification fails'
    mkdir -p "$HOME/.cumaru/bge-micro-v2"
    printf 'retained weights\n' > "$HOME/.cumaru/bge-micro-v2/model.safetensors"
    printf '{}\n' > "$HOME/.cumaru/bge-micro-v2/manifest.json"
    cli model release >/dev/null
    When call cli model pull bge-micro-v2
    The status should equal 1
    The output should be blank
    The error should include 'invalid installed model manifest'
    The path "$HOME/.cumaru/bge-micro-v2/.released" should be file
    The contents of file "$HOME/.cumaru/bge-micro-v2/model.safetensors" should equal 'retained weights'
    The contents of file "$CUMARU_TEST_REQUESTS" should not include huggingface.co
  End

  It 'rejects the retired push spelling without network access'
    When call cli model push bge-micro-v2
    The status should equal 2
    The output should be blank
    The error should include 'unrecognized subcommand'
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'rejects a model name supplied to release'
    When call cli model release bge-micro-v2
    The status should equal 2
    The output should be blank
    The error should include 'unexpected argument'
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End
End
