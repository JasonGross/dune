open! Stdune
open Import

val setup_rules :
     sctx:Super_context.t
  -> dir:Path.Build.t
  -> Dune_file.Plugin.t
  -> unit

val install_rules :
     sctx:Super_context.t
  -> dir:Path.Build.t
  -> Dune_file.Plugin.t
  -> (Loc.t option * Path.Build.t Install.Entry.t) list
