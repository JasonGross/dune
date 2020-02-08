open! Stdune

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

let compare : t -> t -> Ordering.t = Poly.compare


let to_dyn x =
  let open Dyn.Encoder in
  match x with
  | Lib -> constr "Lib" []
  | Lib_root -> constr "Lib_root" []
  | Libexec -> constr "Libexec" []
  | Libexec_root -> constr "Libexec_root" []
  | Bin -> constr "Bin" []
  | Sbin -> constr "Sbin" []
  | Toplevel -> constr "Toplevel" []
  | Share -> constr "Share" []
  | Share_root -> constr "Share_root" []
  | Etc -> constr "Etc" []
  | Doc -> constr "Doc" []
  | Stublibs -> constr "Stublibs" []
  | Man -> constr "Man" []
  | Misc -> constr "Misc" []

module Key = struct type nonrec t = t let compare = compare let to_dyn = to_dyn end
module O = Comparable.Make (Key)
module Map = O.Map
module Set = O.Set


let to_string = function
  | Lib -> "lib"
  | Lib_root -> "lib_root"
  | Libexec -> "libexec"
  | Libexec_root -> "libexec_root"
  | Bin -> "bin"
  | Sbin -> "sbin"
  | Toplevel -> "toplevel"
  | Share -> "share"
  | Share_root -> "share_root"
  | Etc -> "etc"
  | Doc -> "doc"
  | Stublibs -> "stublibs"
  | Man -> "man"
  | Misc -> "misc"

let of_string = function
  | "lib" -> Some Lib
  | "lib_root" -> Some Lib_root
  | "libexec" -> Some Libexec
  | "libexec_root" -> Some Libexec_root
  | "bin" -> Some Bin
  | "sbin" -> Some Sbin
  | "toplevel" -> Some Toplevel
  | "share" -> Some Share
  | "share_root" -> Some Share_root
  | "etc" -> Some Etc
  | "doc" -> Some Doc
  | "stublibs" -> Some Stublibs
  | "man" -> Some Man
  | "misc" -> Some Misc
  | _ -> None

let parse_string s =
  match of_string s with
  | Some s -> Ok s
  | None -> Error (sprintf "invalid section: %s" s)

let decode =
  let open Dune_lang.Decoder in
  enum
    [ ("lib", Lib)
    ; ("lib_root", Lib_root)
    ; ("libexec", Libexec)
    ; ("libexec_root", Libexec_root)
    ; ("bin", Bin)
    ; ("sbin", Sbin)
    ; ("toplevel", Toplevel)
    ; ("share", Share)
    ; ("share_root", Share_root)
    ; ("etc", Etc)
    ; ("doc", Doc)
    ; ("stublibs", Stublibs)
    ; ("man", Man)
    ; ("misc", Misc)
    ]


let encode v =
  let open Dune_lang.Encoder in
  string (to_string v)

let all =
  Set.of_list
    [ Lib
    ; Lib_root
    ; Libexec
    ; Libexec_root
    ; Bin
    ; Sbin
    ; Toplevel
    ; Share
    ; Share_root
    ; Etc
    ; Doc
    ; Stublibs
    ; Man
    ; Misc
    ]

let should_set_executable_bit = function
  | Lib
  | Lib_root
  | Toplevel
  | Share
  | Share_root
  | Etc
  | Doc
  | Man
  | Misc ->
    false
  | Libexec
  | Libexec_root
  | Bin
  | Sbin
  | Stublibs ->
    true

module Site = struct
  module T =
    Interned.Make
      (struct
        let initial_size = 16

        let resize_policy = Interned.Conservative

        let order = Interned.Natural
      end)
      ()

  include T

    include (
    Stringlike.Make (struct
      type t = T.t

      let to_string = T.to_string

      let module_ = "Section.Site"

      let description = "site name"

      let description_of_valid_string = None

      let of_string_opt s =
        (* TODO verify no dots or spaces *)
        if s = "" then
          None
        else
          Some (make s)
    end) :
      Stringlike_intf.S with type t := t )

  let pp fmt t = Format.pp_print_string fmt (to_string t)

  module Infix = Comparator.Operators (T)
end
