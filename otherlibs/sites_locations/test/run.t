Test embedding of sites locations information
-----------------------------------

  $ mkdir -p a b c

  $ for i in a b; do
  > mkdir -p $i
  > cat >$i/dune-project <<EOF
  > (lang dune 2.2)
  > (name $i)
  > (package (name $i) (sites_locations (share data)))
  > EOF
  > done

  $ for i in c; do
  >   mkdir -p $i
  >   cat >$i/dune-project <<EOF
  > (lang dune 2.2)
  > (name $i)
  > (package (name $i) (sites_locations (share data) (lib plugins)))
  > EOF
  > done

  $ cat >a/dune <<EOF
  > (library
  >  (public_name a)
  >  (libraries dune-sites-locations)
  > )
  > (sites (module sites) (package a))
  > EOF

  $ cat >a/a.ml <<EOF
  > let v = "a"
  > let () = Printf.printf "run a\n%!"
  > let () = List.iter (Printf.printf "a: %s\n%!") Sites.data
  > EOF

  $ cat >b/dune <<EOF
  > (library
  >  (public_name b)
  >  (libraries c.register dune-sites-locations)
  > )
  > (sites (module sites) (package b))
  > (plugin (name c-plugins-b) (libraries b) (site (c plugins)))
  > EOF

  $ cat >b/b.ml <<EOF
  > let v = "b"
  > let () = Printf.printf "run b\n%!"
  > let () = C_register.b_registered := true
  > let () = List.iter (Printf.printf "b: %s\n%!") Sites.data
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
  > (sites (module sites) (package c))
  > (rule
  >  (targets out.log)
  >  (deps (package c))
  >  (action (with-stdout-to out.log (run %{bin:c}))))
  > EOF

  $ cat >c/c_register.ml <<EOF
  > let b_registered = ref false
  > EOF

  $ cat >c/c.ml <<EOF
  > let () = Printf.printf "run c: %s b_registered:%b\n%!" A.v !C_register.b_registered
  > let path_sep = if Sys.win32 then ";" else ":"
  > let env_ocamlpath = (String.concat path_sep (Sites.plugins@[Sys.getenv "OCAMLPATH"]))
  > let () = Findlib.init ~env_ocamlpath ()
  > let plugins =
  >  List.concat
  >   (List.map (fun dir -> (Array.to_list (Sys.readdir dir)))
  >     ((List.filter Sys.file_exists Sites.plugins)))
  > let () = Fl_dynload.load_packages plugins
  > let () = Printf.printf "run c: %s b_registered:%b\n%!" A.v !C_register.b_registered
  > let () = List.iter (Printf.printf "c: %s\n%!") Sites.data
  > EOF

  $ cat > dune-project << EOF
  > (lang dune 2.2)
  > EOF

  $ dune build
  $ dune install --prefix _install 2> /dev/null

Inside _build, we have no sites information:

  $ _build/default/c/c.exe
  run a
  run c: a b_registered:false
  run c: a b_registered:false

Once installed, we have the sites information:

  $ OCAMLPATH=_install/lib:$OCAMLPATH _install/bin/c
  run a
  a: $TESTCASE_ROOT/_install/share/a/data
  run c: a b_registered:false
  run b
  b: $TESTCASE_ROOT/_install/share/b/data
  run c: a b_registered:true
  c: $TESTCASE_ROOT/_install/share/c/data

Test substitution when promoting
--------------------------------

  $ c/c.exe
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run c: a b_registered:false
  Fatal error: exception Fl_package_base.No_such_package("b", "required by `c-plugins-b'")
  [2]

Test within dune rules
--------------------------------
  $ dune build c/out.log

  $ cat _build/default/c/out.log
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run c: a b_registered:false
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: a b_registered:true
  c: $TESTCASE_ROOT/_build/install/default/share/c/data


Test with dune exec
--------------------------------
  $ dune exec -- c/c.exe
  run a
  a: $TESTCASE_ROOT/_build/install/default/share/a/data
  run c: a b_registered:false
  run b
  b: $TESTCASE_ROOT/_build/install/default/share/b/data
  run c: a b_registered:true
  c: $TESTCASE_ROOT/_build/install/default/share/c/data
