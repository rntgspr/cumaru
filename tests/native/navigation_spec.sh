Include tests/native/helpers.sh

Describe 'native navigation adapted from legacy tree/map cases'
  BeforeEach 'tree_setup'
  AfterEach 'native_cleanup'

  It 'lists sorted shallow TSV candidates without hidden or unindexed paths'
    When call cli tree
    The status should equal 0
    The output should equal "alpha.md	Alpha behavior provides stable selection context.
area/	Area contracts group related behavior for navigation.
zeta.md	Zeta behavior provides stable selection context."
    The error should be blank
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'normalizes file targets and deduplicates overlapping targets'
    When call cli tree alpha.md . --rows
    The status should equal 0
    The output should equal "alpha.md	Alpha behavior provides stable selection context.
area/	Area contracts group related behavior for navigation.
zeta.md	Zeta behavior provides stable selection context."
    The error should be blank
  End

  It 'retains valid rows after deep navigation defects'
    write_md "$PROJECT/.cumaru/unindexed/leaf.md" 'A valid leaf remains discoverable below a missing index.'
    write_md "$PROJECT/.cumaru/bad.md" 'too short'
    When call cli tree --deep
    The status should equal 1
    The output should include 'unindexed/leaf.md'
    The output should not include 'bad.md'
    The error should include 'unindexed/index.md'
    The error should include 'bad.md'
  End

  Context 'summary boundaries'
    Parameters
      31 1
      32 0
      512 0
      513 1
    End
    It 'classifies exact code-point limits from the legacy matrix'
      rm -r "$PROJECT/.cumaru/unindexed"
      summary=$(printf "%${1}s" '' | tr ' ' a)
      write_md "$PROJECT/.cumaru/candidate.md" "$summary"
      When call cli tree --deep
      The status should equal "$2"
      if [ "$2" = 0 ]; then
        The output should include candidate.md
        The error should be blank
      else
        The output should not include candidate.md
        The error should include candidate.md
      fi
    End
  End

  Context 'unsafe targets'
    Parameters
      /tmp
      area/../alpha.md
      .hidden.md
    End
    It 'rejects before rows without mutating the project'
      before=$(snapshot)
      When call cli tree "$1"
      The status should equal 1
      The output should be blank
      The error should not be blank
      The value "$(snapshot)" should equal "$before"
    End
  End

  It 'maps literal H1-H6 headings with markers and numeric source order'
    printf '# One\n2\n3\n4\n5\n## Six\n```\n### Eight\n```\n10\n11\n###### Twelve\n' > "$PROJECT/.cumaru/order.md"
    When call cli map order.md
    The status should equal 0
    The output should equal "order.md	1	# One
order.md	6	## Six
order.md	8	### Eight
order.md	12	###### Twelve"
    The error should be blank
  End

  It 'reports symlinks and malformed UTF-8 while retaining safe map rows'
    printf '\377\n' > "$PROJECT/.cumaru/invalid.md"
    ln -s alpha.md "$PROJECT/.cumaru/link.md"
    When call cli map
    The status should equal 1
    The output should include "alpha.md	5	# Fixture"
    The output should not include 'link.md'
    The error should include invalid.md
    The error should include link.md
  End

  Context 'retired native flags'
    Parameters
      tree --pillars
      map --domain
      install --from
    End
    It 'rejects legacy-only invocations as usage errors'
      When call cli "$1" "$2" legacy
      The status should equal 2
      The output should be blank
      The error should include 'unexpected argument'
    End
  End

  It 'rejects the removed typed tag mode as a usage error'
    When call cli tag all --rows
    The status should equal 2
    The output should be blank
    The error should not be blank
  End
End
