(** Provide locations information *)

module V1 : sig

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

  module Private_ : sig
    val site : package:string -> section:Section.t ->
      suffix:string -> encoded:string -> Location.t list
  end
end
