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
    The output should equal "order.md:1,12	# One
order.md:6,12	## Six
order.md:8,12	### Eight
order.md:12,12	###### Twelve"
    The error should be blank
  End

  It 'ends each section before the next heading of the same or higher level'
    printf '# A\n## B\n### C\nc\n## D\nd\n# E\n' > "$PROJECT/.cumaru/ends.md"
    When call cli map ends.md
    The status should equal 0
    The output should equal "ends.md:1,6	# A
ends.md:2,4	## B
ends.md:3,4	### C
ends.md:5,6	## D
ends.md:7,7	# E"
    The error should be blank
  End

  It 'gets headed line selections in argument order'
    printf 'one\ntwo\nthree\nfour\n' > "$PROJECT/.cumaru/lines.md"
    When call cli get 'lines.md:3,$' 'lines.md:,2' 'lines.md:2,+1'
    The status should equal 0
    The output should equal "==> lines.md:3,4 <==
three
four

==> lines.md:1,2 <==
one
two

==> lines.md:2,3 <==
two
three"
    The error should be blank
  End

  It 'trims blank edges from map ends and get selections'
    printf '# A\n\na\n\n\n# B\nb\n' > "$PROJECT/.cumaru/blank.md"
    When call cli get blank.md:1,5 blank.md:2,4
    The status should equal 0
    The output should equal "==> blank.md:1,3 <==
# A

a

==> blank.md:3,3 <==
a"
    The error should be blank
  End

  Context 'invalid get selectors'
    Parameters
      'lines.md:,'
      'lines.md:,+1'
      'lines.md:3,1'
      'lines.md:9'
    End
    It 'rejects the whole call with status 2 and no output'
      printf 'one\ntwo\nthree\nfour\n' > "$PROJECT/.cumaru/lines.md"
      When call cli get lines.md:1 "$1"
      The status should equal 2
      The output should be blank
      The error should include 'cumaru get:'
    End
  End

  It 'reports symlinks and malformed UTF-8 while retaining safe map rows'
    printf '\377\n' > "$PROJECT/.cumaru/invalid.md"
    ln -s alpha.md "$PROJECT/.cumaru/link.md"
    When call cli map
    The status should equal 1
    The output should include "alpha.md:5,5	# Fixture"
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
