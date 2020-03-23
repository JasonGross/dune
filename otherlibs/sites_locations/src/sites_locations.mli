(** Provide locations information *)

module Private_ : sig

  module Location : sig
    type t = string
  end


  module Section : sig
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
  end

  val site : package:string -> section:Section.t ->
    suffix:string -> encoded:string -> Location.t list

  val ocamlpath: string -> string
  val sourceroot: string -> string option

  val path_sep: string

end
