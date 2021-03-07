(** Examdomizer
    2021, Stefan Muller

    Read input files *)

open Numtypes

(** A file is a tree of items, which include questions, variant collections
    and variants. *)
type text = string list
type item = Text of text
          | Variants of int * bool * (string option * item list) list
          | Question of (numtype * int) list * bool * item list

type linetype = BeginQ of (numtype * int) list * bool
              | EndQ
              | BeginVs of int * bool
              | EndVs
              | BeginV of string option
              | EndV
              | Normal of string

module SSet = Set.Make(struct type t = string
                              let compare = String.compare
                       end)
             
                      
let linetype l =
  (*  let _ = Printf.printf "%s\n%!" l in *)
  let lt = String.trim l in
  if String.length lt < 3 then Normal l
  else
    if String.sub lt 0 3 = "%%>" then
      (*  let _ = Printf.printf "special\n" in *)
    match String.split_on_char ' ' lt with
    | "%%>"::"begin"::"question"::"randomize"::"order"::t ->
       BeginQ (List.rev (List.map from_example t), true)
    | "%%>"::"begin"::"question"::t ->
       BeginQ (List.rev (List.map from_example t), false)
    | "%%>"::"begin"::"variants"::n::"randomize"::"order"::_ ->
       BeginVs (int_of_string n, true)
    | "%%>"::"begin"::"variants"::n::_ ->
       BeginVs (int_of_string n, false)
    | "%%>"::"begin"::"variant"::s::_ ->
       BeginV (Some s)
    | "%%>"::"begin"::"variant"::_ ->
       BeginV None
    | "%%>"::"end"::"question"::_ -> EndQ
    | "%%>"::"end"::"variants"::_ -> EndVs
    | "%%>"::"end"::"variant"::_ -> EndV
    | _ -> Normal l
  else
    Normal l

exception SyntaxError of int option * string

let labels : SSet.t ref = ref (SSet.empty)

(** Read lines of text. Mutually recursive with readlines_vs, which handles
    variant collections, and readlines_q, which handles questions.
    The item hierarchy is built up in the call stack, items at each level of
    the hierarchy are handled with tail calls.
    @param cur_text text accumulated in current item
    @param items items accumulated in current hierarchy level
    @param ls lines still to read
    @param in_q currently inside a question *)
let rec readlines cur_text items ls in_q =
  (* Throw away text inside a question but not inside a variant *)
  let items' = if in_q then items
               else (Text (List.rev cur_text))::items
  in
  match ls with
  | [] -> (List.rev items', [])
  | (l, n)::t ->
     (match linetype l with
      | BeginV _ ->
         (List.rev items', ls)
      | BeginQ (ns, rand) ->
         let (q, t) = readlines_q t n in
         readlines [] ((Question (ns, rand, q))::items') t in_q
      | BeginVs (no, rand) ->
         let (vs, t) = readlines_vs [] t n false None in
         readlines [] ((Variants (no, rand, vs))::items') t in_q
      | EndQ
        | EndVs
        | EndV ->
         (List.rev items', ls)
      | Normal l -> readlines (l::cur_text) items t in_q)
and readlines_q ls n =
  (* Call readlines to throw out text before variant collections *)
  let (items, t) = readlines [] [] ls true in
  (* When we pop down to this level of the call stack, we must be at the
     end of this question *)
  match t with
  | [] -> raise (SyntaxError (None, "unmatched begin question on line "
                                 ^ (string_of_int n)))
  | (l, n')::t ->
     (match linetype l with
      | EndQ -> (items, t)
      | _ -> raise (SyntaxError (Some n', "unmatched begin question on line "
                                 ^ (string_of_int n))))
and readlines_vs vars ls n invar varname =
  (* Read text, throw it out if we're not actually inside a variant *)
  let (items, t) = readlines [] [] ls false in
  let vars' = if invar then (varname, items)::vars else vars in
  match t with
  | [] -> raise (SyntaxError (None, "unmatched begin variants on line "
                                  ^ (string_of_int n)))
  | (l, n')::t ->
     (* We're either at the start of the next variant or the end of
        this collection *)
     (match linetype l with
      | BeginV vn ->
         let _ =
           match vn with
           | Some l -> if SSet.mem l !labels then
                         raise (SyntaxError (Some n', "duplicate label " ^ l))
                       else
                         labels := SSet.add l !labels
           | None -> ()
         in
         readlines_vs vars' t n' true vn
      | EndVs -> ((List.rev vars'), t)
      | EndV ->
         if not invar then
           raise (SyntaxError (Some n', "end variant without begin"))
         else readlines_vs vars' t n' false None
      | _ -> raise (SyntaxError (Some n', "unmatched begin variants on line "
                                  ^ (string_of_int n))))

(** Read an annotated LaTeX file.
    @raise SyntaxError on syntax errors *)
let readfile (filename: string) =
  let chan = open_in filename in
  let rec inp_lines ls ln =
    try
      inp_lines ((input_line chan, ln)::ls) (ln + 1)
    with
      End_of_file -> List.rev ls
  in
  let ls = inp_lines [] 1 in
  let _ = close_in chan in
  let (items, _) =
    try readlines [] [] ls false
    with SyntaxError (Some l, s) ->
          (Printf.eprintf "Syntax Error, line %d: %s\n" l s;
           exit 1)
       | SyntaxError (None, s) ->
          (Printf.eprintf "Syntax Error at EOF: %s\n" s;
           exit 1)
  in
  items
