(** Provide locations information *)

module V1 : sig

  module Location : sig
    type t = string
  end

  module Private_ : sig

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

    module Plugin : sig
      module type S = sig
        val init: unit -> unit
        val list: unit -> string list
        val load_all: unit -> unit
        val load: string -> unit
      end

      val list: string list -> string list

      val exists: string list -> string -> bool

      val env_ocamlpath: string list -> string -> string

    end

  end
end
