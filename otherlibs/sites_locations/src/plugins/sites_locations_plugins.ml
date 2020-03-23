module Private_ = struct

  let readdir dirs =
    List.concat
      (List.map (fun dir -> (Array.to_list (Sys.readdir dir)))
         (List.filter Sys.file_exists dirs))

  let file_exists dirs plugin =
    List.exists (fun d -> Sys.file_exists (Filename.concat d plugin)) dirs

  module type S = sig
      val paths: string list
      val list: unit -> string list
      val load_all: unit -> unit
      val load: string -> unit
    end

  let new_id = let next_id = ref (-1) in fun () -> incr next_id; !next_id

  let initialized_id = ref (-1)
  let init id paths ocamlpath () =
    if !initialized_id <> id
    then
      let env_ocamlpath =
        String.concat Sites_locations.Private_.path_sep (paths@[ocamlpath])
      in
      Findlib.init ~env_ocamlpath ()

  module Make (X:sig val paths: string list val ocamlpath: string end) : S = struct
    include X
    let id = new_id ()
    let init () = init id paths ocamlpath ()
    let list () = readdir paths
    let load_all () = init (); Fl_dynload.load_packages (list ())
    let exists name = file_exists paths name
    let load name =
      if exists name
      then begin init (); Fl_dynload.load_packages [name] end
      else raise Not_found
    end

end
