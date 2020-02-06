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

val compare: t -> t -> Ordering.t

include Comparable_intf.S with type Key.t = t

val to_string : t -> string
val of_string : string -> t option

val parse_string : string -> (t, string) Result.t

val decode : t Dune_lang.Decoder.t
val encode : t Dune_lang.Encoder.t

val to_dyn : t -> Dyn.t
