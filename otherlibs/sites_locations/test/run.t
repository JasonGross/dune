Test embedding of sites locations information
-----------------------------------

  $ mkdir -p a b c

  $ for i in a b; do
  > mkdir -p $i
  > cat >$i/dune-project <<EOF
  > (lang dune 2.2)
  > (name $i)
  > (package (name $i) (sites (share data)))
  > EOF
  > done

  $ for i in c; do
  >   mkdir -p $i
  >   cat >$i/dune-project <<EOF
  > (lang dune 2.2)
  > (name $i)
  > (package (name $i) (sites (share data) (lib plugins)))
  > EOF
  > done

  $ cat >a/dune <<EOF
  > (library
  >  (public_name a)
  >  (libraries dune-sites-locations)
  > )
  > (generate_module (module sites) (sites a))
  > EOF

  $ cat >a/a.ml <<EOF
  > let v = "a"
  > let () = Printf.printf "run a\n%!"
  > let () = List.iter (Printf.printf "a: %s\n%!") Sites.Sites.A.data
  > EOF

  $ cat >b/dune <<EOF
  > (library
  >  (public_name b)
  >  (libraries c.register dune-sites-locations)
  > )
  > (generate_module (module sites) (sites b))
  > (plugin (name c-plugins-b) (libraries b) (site (c plugins)))
  > EOF

  $ cat >b/b.ml <<EOF
  > let v = "b"
  > let () = Printf.printf "run b\n%!"
  > let () = C_register.b_registered := true
  > let () = List.iter (Printf.printf "b: %s\n%!") Sites.Sites.B.data
  > EOF

  $ cat >c/dune <<EOF
  > (executable
  >  (public_name c)
  >  (promote (until-clean))
  >  (modules c sites)
  >  (libraries a c.register findlib.dynload dune-sites-locations))
  > (library
  >  (public_name c.register)
  >  (name c_register)
  >  (modules c_register)
  > )
  > (generate_module (module sites) (sourceroot) (plugins (c plugins)))
  > (rule
  >  (targets out.log)
  >  (deps (package c))
  >  (action (with-stdout-to out.log (run %{bin:c}))))
  > EOF

  $ cat >c/c_register.ml <<EOF
  > let b_registered = ref false
  > EOF

  $ cat >c/c.ml <<EOF
  > let () = Printf.printf "run c: %s linked b_registered:%b\n%!"
  >   A.v !C_register.b_registered
  > let () = match Sites.sourceroot with
  >       | Some d -> Printf.printf "sourceroot is %S\n%!" d
  >       | None -> Printf.printf "no sourceroot\n%!"
  > let () = List.iter (Printf.printf "c: %s\n%!") Sites.Sites.C.data
  > let () = Sites.Plugins.C.Plugins.init ()
  > let () = Sites.Plugins.C.Plugins.load_all ()
  > let () = Printf.printf "run c: b_registered:%b\n%!" !C_register.b_registered
  > EOF

  $ cat > dune-project << EOF
  > (lang dune 2.2)
  > EOF

  $ dune build

  $ dune install --prefix _install 2> /dev/null

Inside _build, we have no sites information:

  $ _build/default/c/c.exe
  run a
  run c: a linked b_registered:false
  no sourceroot
  run c: b_registered:false

Once installed, we have the sites information:

  $ OCAMLPATH=_install/lib:$OCAMLPATH _install/bin/c
  run a
  a: $TESTCASE_ROOT/_install/share/a/data
  run c: a linked b_registered:false
  no sourceroot
  c: $TESTCASE_ROOT/_install/share/c/data
  run b
  b: $TESTCASE_ROOT/_install/share/b/data
  run c: b_registered:true

Test substitution when promoting
--------------------------------

  $ c/c.exe
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run c: a linked b_registered:false
  sourceroot is "$TESTCASE_ROOT"
  c: $TESTCASE_ROOT/_build/install/default/share/c/data
  run b
  run c: b_registered:true

Test within dune rules
--------------------------------
  $ dune build c/out.log

  $ cat _build/default/c/out.log
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run c: a linked b_registered:false
  sourceroot is "$TESTCASE_ROOT"
  c: $TESTCASE_ROOT/_build/install/default/share/c/data
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: b_registered:true


Test with dune exec
--------------------------------
  $ dune exec -- c/c.exe
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run c: a linked b_registered:false
  sourceroot is "$TESTCASE_ROOT"
  c: $TESTCASE_ROOT/_build/install/default/share/c/data
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: b_registered:true
