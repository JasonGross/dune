open Stdune

module Buildable = Dune_file.Buildable

module Virtual = struct
  type t =
    { virtual_modules : Ordered_set_lang.t
    }
end

module Implementation = struct
  type t =
    { existing_virtual_modules : Module.Name.Set.t
    ; allow_new_public_modules : bool
    }
end

type kind =
  | Virtual of Virtual.t
  | Implementation of Implementation.t
  | Exe_or_normal_lib

let eval =
  let module Value = struct
    type t = (Module.Source.t, Module.Name.t) result

    type key = Module.Name.t

    let key = function
      | Error s -> s
      | Ok m -> Module.Source.name m
  end in
  let module Eval = Ordered_set_lang.Make_loc(Module.Name)(Value) in
  let parse ~all_modules ~fake_modules ~loc s =
    let name = Module.Name.of_string s in
    match Module.Name.Map.find all_modules name with
    | Some m -> Ok m
    | None ->
      fake_modules := Module.Name.Map.add !fake_modules name loc;
      Error name
  in
  fun ~all_modules ~standard osl ->
    let fake_modules = ref Module.Name.Map.empty in
    let parse = parse ~fake_modules ~all_modules in
    let standard = Module.Name.Map.map standard ~f:(fun m -> Ok m) in
    let modules = Eval.eval_unordered ~parse ~standard osl in
    ( !fake_modules
    , Module.Name.Map.filter_map modules ~f:(fun (loc, m) ->
        match m with
        | Ok m -> Some (loc, m)
        | Error s ->
          (* We are going to fail only if the module appear in the final set,
             foo \ bar doesn't fail if bar doesn't exists (for jbuild file
             compatibility) *)
          Errors.fail loc "Module %a doesn't exist." Module.Name.pp s)
    )

type errors =
  { spurious_modules_intf    : (Loc.t * Module.Name.t) list
  ; spurious_modules_virtual : (Loc.t * Module.Name.t) list
  ; missing_intf_only        : (Loc.t * Module.Name.t) list
  ; virt_intf_overlaps       : (Loc.t * Module.Name.t) list
  ; private_virt_modules     : (Loc.t * Module.Name.t) list
  ; private_impl_of_vmodule  : (Loc.t * Module.Name.t) list
  ; vmodule_impl_intf_only_exclusion : (Loc.t * Module.Name.t) list
  ; vmodule_impl_missing_impl : (Loc.t * Module.Name.t) list
  ; forbidden_new_public_modules : (Loc.t * Module.Name.t) list
  ; unimplemented_virt_modules : Module.Name.Set.t
  }

module Properties = struct
  type t =
    | Modules
    | Private
    | Virtual
    | Intf_only

  let tag = function
    | Modules -> 0
    | Private -> 1
    | Virtual -> 2
    | Intf_only -> 3

  let compare a b = compare (tag a) (tag b)

  module Map = Map.Make(struct type nonrec t = t let compare = compare end)

  let add prop =
    Module.Name.Map.map
      ~f:(fun (loc, module_) -> module_, Map.singleton prop loc)

  let union m1 m2 =
    Module.Name.Map.union m1 m2
      ~f:(fun _ (module_, l1) (_, l2) ->
        Some (module_, Map.union l1 l2 ~f:(fun _ _ -> assert false)))
end


let find_errors ~modules ~intf_only ~virtual_modules ~private_modules
      ~existing_virtual_modules ~allow_new_public_modules =
  let modules = Properties.add Modules modules in
  let intf_only = Properties.add Intf_only intf_only in
  let virtual_modules = Properties.add Virtual virtual_modules in
  let private_modules = Properties.add Private private_modules in
  let all : (Module.Source.t * Loc.t Properties.Map.t) Module.Name.Map.t =
    let union = Properties.union in
    union modules (union intf_only (union virtual_modules private_modules))
  in
  let spurious_modules_intf    = ref [] in
  let spurious_modules_virtual = ref [] in
  let virt_intf_overlaps       = ref [] in
  let private_virt_modules     = ref [] in
  let missing_intf_only        = ref [] in
  let unimplemented_virt_modules = ref existing_virtual_modules in
  let private_impl_of_vmodule  = ref [] in
  let vmodule_impl_intf_only_exclusion = ref [] in
  let forbidden_new_public_modules = ref [] in
  let vmodule_impl_missing_impl = ref [] in
  Module.Name.Map.iteri all ~f:(fun module_name (module_, props) ->
    let has_impl = Module.Source.has_impl module_ in
    let impl_vmodule =
      Module.Name.Set.mem existing_virtual_modules module_name in
    let (!?) p = Properties.Map.mem props p in
    let (!??) p f = Option.iter ~f (Properties.Map.find props p) in
    let add_to stack loc = stack := (loc, module_name) :: !stack in
    !?? Private (fun loc ->
      if impl_vmodule then
        add_to private_impl_of_vmodule loc;
    );
    !?? Intf_only (fun loc ->
      if has_impl then add_to spurious_modules_intf loc;
      if impl_vmodule then add_to vmodule_impl_intf_only_exclusion loc;
    );
    !?? Virtual (fun loc ->
      if    has_impl  then add_to spurious_modules_virtual loc;
      if !? Intf_only then add_to virt_intf_overlaps loc;
      if !? Private   then add_to private_virt_modules loc;
    );
    !?? Modules (fun loc ->
      if not (!? Private)
      && not allow_new_public_modules
         && not impl_vmodule then
        add_to forbidden_new_public_modules loc;
      if not has_impl && not !? Intf_only && not !? Virtual then
        add_to missing_intf_only loc;
      if impl_vmodule then begin
        if has_impl then
          unimplemented_virt_modules :=
            Module.Name.Set.remove !unimplemented_virt_modules
              module_name
        else
          add_to vmodule_impl_missing_impl loc
      end
    );
  );
  { spurious_modules_intf    = List.rev !spurious_modules_intf
  ; spurious_modules_virtual = List.rev !spurious_modules_virtual
  ; virt_intf_overlaps       = List.rev !virt_intf_overlaps
  ; private_virt_modules     = List.rev !private_virt_modules
  ; missing_intf_only        = List.rev !missing_intf_only
  ; unimplemented_virt_modules = !unimplemented_virt_modules
  ; private_impl_of_vmodule = List.rev !private_impl_of_vmodule
  ; vmodule_impl_intf_only_exclusion =
      List.rev !vmodule_impl_intf_only_exclusion
  ; vmodule_impl_missing_impl = List.rev !vmodule_impl_missing_impl
  ; forbidden_new_public_modules = List.rev !forbidden_new_public_modules
  }

let check_invalid_module_listing ~(buildable : Buildable.t) ~intf_only
      ~modules ~virtual_modules ~private_modules ~existing_virtual_modules
      ~allow_new_public_modules =
  let { spurious_modules_intf
      ; spurious_modules_virtual
      ; virt_intf_overlaps
      ; private_virt_modules
      ; missing_intf_only
      ; unimplemented_virt_modules
      ; private_impl_of_vmodule
      ; vmodule_impl_intf_only_exclusion
      ; vmodule_impl_missing_impl
      ; forbidden_new_public_modules
      } =
    find_errors ~modules ~intf_only ~virtual_modules ~private_modules
      ~existing_virtual_modules ~allow_new_public_modules
  in
  let uncapitalized =
    List.map ~f:(fun (_, m) -> Module.Name.uncapitalize m) in
  let line_list modules =
    List.map ~f:(fun (_, m) ->
      m |> Module.Name.to_string |> sprintf "- %s") modules
    |> String.concat ~sep:"\n"
  in
  let print fmt l =
    match l with
    | [] -> ()
    | (loc, _) :: _ ->
      Errors.fail loc fmt (line_list l)
  in
  print "Implementations of wrapped libraries cannot introduce new \
         public modules.\nThe following modules:\
         \n%s\n must all be marked as private using the \
         (private_modules ..) field."
    forbidden_new_public_modules;
  print "The following modules implement virtual modules but \
         do not have implementations:\
         \n%s\nYou must provide implementations for these"
    vmodule_impl_missing_impl;
  print "These modules are supposed to be implemented:\
         \n%s\nThey cannot be intferface only"
    vmodule_impl_intf_only_exclusion;
  print "These modules are virtual modules implementations:\
        \n%s\nThey cannot be private"
    private_impl_of_vmodule;
  print
    "The following modules are declared as virtual and private:\
     \n%s\nThis is not possible."
    private_virt_modules;
  print "These modules appear in the virtual_libraries \
         and modules_without_implementation fields:\
         \n%s\nThis is not possible."
    virt_intf_overlaps;
  print "These modules are declared virtual, but are missing.\
         \n%s\n\
         You must provide an implementation for all of these modules."
    (unimplemented_virt_modules
     |> Module.Name.Set.to_list
     |> List.map ~f:(fun name -> (buildable.loc, name)));
  if missing_intf_only <> [] then begin
    match Ordered_set_lang.loc buildable.modules_without_implementation with
    | None ->
      (* DUNE2: turn this into an error *)
      Errors.warn buildable.loc
        "Some modules don't have an implementation.\
         \nYou need to add the following field to this stanza:\
         \n\
         \n  %s\
         \n\
         \nThis will become an error in the future."
        (let tag =
           Dune_lang.unsafe_atom_of_string "modules_without_implementation" in
         let modules =
           missing_intf_only
           |> uncapitalized
           |> List.map ~f:Dune_lang.Encoder.string
         in
         Dune_lang.to_string ~syntax:Dune (List (tag :: modules)))
    | Some loc ->
      (* DUNE2: turn this into an error *)
      Errors.warn loc
        "The following modules must be listed here as they don't \
         have an implementation:\n\
         %s\n\
         This will become an error in the future."
        (line_list missing_intf_only)
  end;
  print
    "The following modules have an implementation, \
     they cannot be listed as modules_without_implementation:\n%s"
    spurious_modules_intf;
  print "The following modules have an implementation, \
         they cannot be listed as virtual:\n%s"
    spurious_modules_virtual

let eval ~modules:(all_modules : Module.Source.t Module.Name.Map.t)
      ~buildable:(conf : Buildable.t) ~private_modules ~kind =
  (* fake modules are modules that doesn't exists but it doesn't
     matter because they are only removed from a set (for jbuild file
     compatibility) *)
  let fake_modules = ref Module.Name.Map.empty in
  let add_fake_modules (fake_modules', a) =
    fake_modules := Module.Name.Map.superpose fake_modules' !fake_modules;
    a
  in
  let modules =
    add_fake_modules @@
    eval ~standard:all_modules ~all_modules conf.modules
  in
  let intf_only =
    add_fake_modules @@
    eval ~standard:Module.Name.Map.empty ~all_modules
      conf.modules_without_implementation
  in
  let allow_new_public_modules =
    match kind with
    | Exe_or_normal_lib
    | Virtual _ -> true
    | Implementation { allow_new_public_modules ; _ } ->
      allow_new_public_modules
  in
  let existing_virtual_modules =
    match kind with
    | Exe_or_normal_lib
    | Virtual _ -> Module.Name.Set.empty
    | Implementation { existing_virtual_modules; _ } -> existing_virtual_modules
  in
  let virtual_modules =
    match kind with
    | Exe_or_normal_lib
    | Implementation _ -> Module.Name.Map.empty
    | Virtual { virtual_modules } ->
      add_fake_modules @@
      eval ~standard:Module.Name.Map.empty ~all_modules virtual_modules
  in
  let private_modules =
    add_fake_modules @@
    eval ~standard:Module.Name.Map.empty ~all_modules private_modules
  in
  Module.Name.Map.iteri !fake_modules ~f:(fun m loc ->
    (* DUNE2: make this an error *)
    Errors.warn loc "Module %a is excluded but it doesn't exist."
      Module.Name.pp m
  );
  check_invalid_module_listing ~buildable:conf ~intf_only
    ~modules ~virtual_modules ~private_modules ~existing_virtual_modules
    ~allow_new_public_modules;
  let all_modules =
    Module.Name.Map.map modules ~f:(fun (_, m) ->
      let name = Module.Source.name m in
      let visibility =
        if Module.Name.Map.mem private_modules name then
          Visibility.Private
        else
          Public
      in
      let kind =
        if Module.Name.Map.mem virtual_modules name then
          Module.Kind.Virtual
        else if Module.Source.has_impl m then
          let name = Module.Source.name m in
          if Module.Name.Set.mem existing_virtual_modules name then
            Impl_vmodule
          else
            Impl
        else
          Intf_only
      in
      Module.of_source m ~kind ~visibility)
  in
  all_modules
