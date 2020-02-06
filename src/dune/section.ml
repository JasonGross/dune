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
