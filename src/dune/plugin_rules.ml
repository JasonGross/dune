open! Stdune
open Dune_file.Plugin

let meta_file ~dir {name; libraries=_; site=(_,(pkg,site)); _} =
  let dir = Path.Build.relative dir ".site" in
  let dir = Path.Build.relative dir (Package.Name.to_string pkg) in
  let dir = Path.Build.relative dir (Package.Name.to_string site) in
  let dir = Path.Build.relative dir (Package.Name.to_string name) in
  let meta_file = Path.Build.relative dir "META" in
  meta_file

let setup_rules ~sctx ~dir t =
  let meta = meta_file ~dir t in
  Build.delayed
    (fun () ->
       let libs =
         Result.List.map
           t.libraries
           ~f:(Lib.DB.resolve (Super_context.public_libs sctx)) in
       let requires =
         match libs with
         | Ok l -> List.map l ~f:(fun lib -> Lib_name.to_string (Lib.name lib))
         | Error e -> raise e
       in
       let meta = {
         Meta.name = None;
         entries = [
           Rule { Meta.var = "requires"; action = Set; predicates = [];
             value = String.concat ~sep:" " requires
           } ]
       } in
       Format.asprintf "@[<v>%a@,@]" Pp.render_ignore_tags (Meta.pp meta.entries))
  |> Build.write_file_dyn meta
  |> Super_context.add_rule sctx ~dir


let install_rules ~sctx ~dir ({name; site=(loc,(pkg,site));_} as t) =
  let meta = meta_file ~dir t in
  [Some loc,Install.Entry.make_with_site
              ~dst:(sprintf "%s/%s" (Package.Name.to_string name) "META")
              (Site {pkg;site})
              ((Super_context.get_site_of_packages sctx))
              meta]
