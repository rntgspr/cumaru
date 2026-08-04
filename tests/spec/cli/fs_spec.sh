Include tests/spec/cli/support/helpers.sh

Describe 'cumaru fs'
  BeforeEach 'fs_setup'
  AfterEach 'fs_cleanup'

  Context 'with valid operations'
    Parameters
      'plans/new' create '' 'create: plans/new/ (dir)'
      'plans/new/note.md' create '' 'create: plans/new/note.md (file)'
      'plans/item/note.md' move 'archive/moved/note.md' 'move: plans/item/note.md'
      'plans/item' copy 'archive/item' 'copy: plans/item'
      'plans/item/note.md' remove '' 'remove: plans/item/note.md'
      'plans/item' remove '' 'remove: plans/item'
    End
    It 'performs each verb and reports the exact operation'
      if [ -n "$3" ]; then
        When call cli_in "$FS_PROJECT" fs "$1" "$2" "$3"
      else
        When call cli_in "$FS_PROJECT" fs "$1" "$2"
      fi
      The status should be success
      The output should include "$4"
      The error should be blank
    End
  End

  It 'moves exactly one directory tree'
    When call cli_in "$FS_PROJECT" fs plans/item move archive/item
    The status should be success
    The output should include 'move: plans/item'
    The path "$FS_PROJECT/.cumaru/plans/item" should not be exist
    The path "$FS_PROJECT/.cumaru/archive/item/index.md" should be file
    The path "$FS_PROJECT/.cumaru/archive/item/note.md" should be file
    The error should be blank
  End

  It 'copies exactly one file and leaves its source intact'
    When call cli_in "$FS_PROJECT" fs plans/item/note.md copy archive/copied/note.md
    The status should be success
    The output should include 'copy: plans/item/note.md'
    The path "$FS_PROJECT/.cumaru/plans/item/note.md" should be file
    The path "$FS_PROJECT/.cumaru/archive/copied/note.md" should be file
    The value "$(cksum < "$FS_PROJECT/.cumaru/plans/item/note.md")" should equal "$(cksum < "$FS_PROJECT/.cumaru/archive/copied/note.md")"
    The error should be blank
  End

  Context 'with invalid operations'
    Parameters
    '/tmp' remove '' 1 'must be relative'
    'plans/../item' remove '' 1 'segments not allowed'
    'plans/./item' remove '' 1 'segments not allowed'
    'plans/item' dance '' 2 'unknown verb'
    'plans/item' move '' 2 'requires <dst>'
    'plans/item' move 'archive/item extra' 2 'too many arguments'
    'plans/item/data.txt' remove '' 1 'file must end in .md'
    'plans/item.v2' create '' 1 'directory names must not contain dots'
    'plans/item/index.md' remove '' 1 'cannot remove an index.md'
    'plans' remove '' 1 'cannot remove a pillar root'
    'plans/missing.md' move 'archive/missing.md' 1 'source not found'
    'plans/item/note.md' move 'archive/index.md' 1 'destination already exists'
    'plans/item/note.md' copy 'archive/index.md' 1 'destination already exists'
    End
    It 'rejects without mutation'
      before=$(fs_snapshot)
      if [ "$2" = move ] && [ "$3" = 'archive/item extra' ]; then
        When call cli_in "$FS_PROJECT" fs "$1" "$2" archive/item extra
      elif [ -n "$3" ]; then
        When call cli_in "$FS_PROJECT" fs "$1" "$2" "$3"
      else
        When call cli_in "$FS_PROJECT" fs "$1" "$2"
      fi
      The status should equal "$4"
      The output should be blank
      The error should include "$5"
      The value "$(fs_snapshot)" should equal "$before"
    End
  End


  It 'rejects a symlinked parent escaping the tree without mutation'
    mkdir -p "$FS_TMP/outside"
    ln -s "$FS_TMP/outside" "$FS_PROJECT/.cumaru/escape"
    before=$(fs_snapshot)
    When call cli_in "$FS_PROJECT" fs escape/new.md create
    The status should be failure
    The output should be blank
    The error should include 'resolves outside .cumaru'
    The value "$(fs_snapshot)" should equal "$before"
    The path "$FS_TMP/outside/new.md" should not be exist
  End

  It 'rejects a direct symlink without mutation'
    ln -s item "$FS_PROJECT/.cumaru/plans/link"
    before=$(fs_snapshot)
    When call cli_in "$FS_PROJECT" fs plans/link remove
    The status should be failure
    The output should be blank
    The error should include 'symlink targets are not supported'
    The value "$(fs_snapshot)" should equal "$before"
  End

  It 'treats no arguments as usage error'
    When call cli_in "$FS_PROJECT" fs
    The status should equal 2
    The output should be blank
    The error should include 'usage:'
  End

  It 'rejects the retired flow command without mutation or workflow execution'
    before=$(fs_snapshot)
    When call cli_in "$FS_PROJECT" flow named-workflow
    The status should equal 2
    The output should be blank
    The error should include "was renamed to 'cumaru fs'"
    The error should include 'workflow execution is not available'
    The value "$(fs_snapshot)" should equal "$before"
  End
End
