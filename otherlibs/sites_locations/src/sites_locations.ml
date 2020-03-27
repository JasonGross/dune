module Private_ = struct
  module Location = struct
    type t = string
  end
  module Section = struct
    type t =
      | Lib
      | Lib_root
      | Libexec
      | Libexec_root
      | Bin
      | Sbin
      | Toplevel
      | Share
      | Share_root
      | Etc
      | Doc
      | Stublibs
      | Man
      | Misc

    let of_string = function
      | "lib" -> Lib
      | "lib_root" -> Lib_root
      | "libexec" -> Libexec
      | "libexec_root" -> Libexec_root
      | "bin" -> Bin
      | "sbin" -> Sbin
      | "toplevel" -> Toplevel
      | "share" -> Share
      | "share_root" -> Share_root
      | "etc" -> Etc
      | "doc" -> Doc
      | "stublibs" -> Stublibs
      | "man" -> Man
      | "misc" -> Misc
      | _ -> assert false (* since produced by Section.to_string *)
  end

  let dirs : (string*Section.t,string) Hashtbl.t = Hashtbl.create 10
  (* multi-bindings first is the one with least priority *)

  let path_sep =
    if Sys.win32 then
      ';'
    else
      ':'

  let () =
    match Sys.getenv_opt "DUNE_DIR_LOCATIONS" with
    | None -> ()
    | Some s ->
      let rec aux = function
        | [] -> ()
        | package::section::dir::l ->
          let section = Section.of_string section in
          Hashtbl.add dirs (package,section) dir;
          aux l
        | _ -> invalid_arg "Error parsing DUNE_DIR_LOCATIONS"
      in
      let l = String.split_on_char path_sep s in
      aux l

  (* Parse the replacement format described in [artifact_substitution.ml]. *)
  let eval s =
    let len = String.length s in
    if s.[0] = '=' then
      let colon_pos = String.index_from s 1 ':' in
      let vlen = int_of_string (String.sub s 1 (colon_pos - 1)) in
      (* This [min] is because the value might have been truncated
         if it was too large *)
      let vlen = min vlen (len - colon_pos - 1) in
      Some (String.sub s (colon_pos + 1) vlen)
    else
      None
  [@@inline never]

  let get_dir ~package ~section =
    Hashtbl.find_all dirs (package,section)

  let relocatable = lazy (
    match eval Sites_locations_data.relocatable_encoded with
    | Some "y" -> true
    | None | Some "n" -> false
    | Some _ -> assert false (* absurd: only y/n are generated *)
  )

  let prefix = lazy (
    let path = Sys.executable_name in
    let bin = Filename.dirname path in
    let prefix = Filename.dirname bin in
    prefix
  )
  let relocate_if_needed path =
    if Lazy.force relocatable then
      Filename.concat (Lazy.force prefix) path
    else
      path

  let site ~package ~section ~suffix ~encoded =
    let dirs = get_dir ~package ~section in
    let dirs = match eval encoded with
      | None -> dirs
      | Some d -> (relocate_if_needed d)::dirs
    in
    List.rev_map (fun dir -> Filename.concat dir suffix) dirs
  [@@inline never]

  let sourceroot local =
    match eval local with
    | Some "" -> None
    | Some _ as x -> x
    | None ->
      (* None if the binary is executed from _build but not by dune, which
         should not happend *)
      Sys.getenv_opt "DUNE_SOURCEROOT"

  let path_sep = if Sys.win32 then ";" else ":"
  let ocamlpath installlib =
    let env = match Sys.getenv_opt "OCAMLPATH" with
      | None -> []
      | Some x -> [x]
    in
    let env = match eval installlib with
      | None | Some "" -> env
      | Some x -> x::env
    in
    let env =
      if Lazy.force relocatable then
        (Filename.concat (Lazy.force prefix) "lib")::env
      else env
    in
    String.concat path_sep env

end
