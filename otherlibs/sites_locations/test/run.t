Test embedding of sites locations information
-----------------------------------

  $ mkdir -p a b c

  $ for i in a b c; do
  >   mkdir -p $i
  >   cat >$i/dune-project <<EOF
  > (lang dune 2.2)
  > (name $i)
  > (package (name $i) (sites_locations (share data)))
  > EOF
  > done

  $ for i in a b; do
  >   cat >$i/dune <<EOF
  > (library
  >  (public_name $i)
  >  (libraries dune-sites-locations)
  > )
  > (sites (module sites) (package $i))
  > EOF
  >   cat >$i/$i.ml <<EOF
  > let v = "$i"
  > let () = Printf.printf "run $i\n%!"
  > let () = List.iter (Printf.printf "$i: %s\n%!") Sites.data
  > EOF
  > done

  $ cat >c/dune <<EOF
  > (executable
  >  (public_name c)
  >  (promote (until-clean))
  >  (libraries a b dune-sites-locations))
  > (sites (module sites) (package c))
  > (rule
  >  (targets out.log)
  >  (deps (package c))
  >  (action (with-stdout-to out.log (run %{bin:c}))))
  > EOF

  $ cat >c/c.ml <<EOF
  > let () = Printf.printf "run c: %s %s\n%!" A.v B.v
  > let () = List.iter (Printf.printf "c: %s\n%!") Sites.data
  > EOF

  $ cat > dune-project << EOF
  > (lang dune 2.0)
  > EOF

  $ dune build
  $ dune install --prefix _install 2> /dev/null

Inside _build, we have no sites information:

  $ _build/default/c/c.exe
  run a
  run b
  run c: a b

Once installed, we have the sites information:

  $ _install/bin/c
  run a
  a: $TESTCASE_ROOT/_install/share/a/data
  run b
  b: $TESTCASE_ROOT/_install/share/b/data
  run c: a b
  c: $TESTCASE_ROOT/_install/share/c/data

Test substitution when promoting
--------------------------------

  $ c/c.exe
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: a b
  c: $TESTCASE_ROOT/_build/install/default/share/c/data

Test within dune rules
--------------------------------
  $ dune build c/out.log

  $ cat _build/default/c/out.log
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: a b
  c: $TESTCASE_ROOT/_build/install/default/share/c/data


Test with dune exec
--------------------------------
  $ dune exec -- c/c.exe
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: a b
  c: $TESTCASE_ROOT/_build/install/default/share/c/data
