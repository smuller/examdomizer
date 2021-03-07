(** Examdomizer
    2021, Stefan Muller

    Generate exams from input files *)

open Numtypes
open Readtex

(** Annotations to hold the question number in generated exam and
    original variant name. *)
type gen_rpt_item =
  { question   : (numtype * int) list;
    path       : (int * int) list;
    label      : string option}

let remove (l: 'a list) (n: int) =
  List.init ((List.length l) - 1)
    (fun i -> if i >= n then List.nth l (i + 1)
              else List.nth l i)
let choose bd n permute =
  let rec choose_bd from num =
    if num <= 0 || from <= 0 then []
    else
      let i = Random.int from in
      i::(choose_bd (from - 1) (num - 1))
  in
  let rec adj_indices l =
    match l with
    | [] -> []
    | i::t ->
       i::(List.map (fun j -> if j >= i then j + 1 else j) (adj_indices t))
  in
  let inds = (adj_indices (choose_bd bd n))
  in
  if permute then inds
  else List.sort (fun a b -> a - b) inds

(** Intermediate representation of exams: tree of text, but without
    questions and collections. *)
type texttree = Leaf of text
              | Node of texttree list * gen_rpt_item option

(* Operations on text trees *)
let revapp_tree e t =
  match t with
  | Leaf t -> Node (List.rev_append e [Leaf t], None)
  | Node (l, r) -> Node (List.rev_append e l, r)

let cons_tree e t =
  match t with
  | Leaf t -> Node ([Leaf e; Leaf t], None)
  | Node (l, r) -> Node ((Leaf e)::l, r)

let rev_tree t =
  match t with
  | Leaf _ -> t
  | Node (l, r) -> Node (List.rev l, r)

let rec flatten (t: texttree) : (text * gen_rpt_item option) list =
  match t with
  | Leaf t -> [(t, None)]
  | Node (l, r) ->
     List.map (function (t, None) -> (t, r)
                      | (t, Some r) -> (t, Some r))
       (List.concat (List.map flatten l))

let print_q q =
  List.fold_left (fun s n -> (Numtypes.render n) ^ s) "" q
    
let rec printtree (ind: int) (t: texttree) =
  match t with
  | Leaf t -> Printf.printf "%sleaf\n" (String.make ind ' ')
  | Node (l, Some r) ->
     (Printf.printf "%s<%s, %s>\n"
        (String.make ind ' ')
        (print_q r.question)
        (match r.label with Some s -> s | None -> "unk");
      List.iter (printtree (ind + 1)) l)
  | Node (l, None) ->
     (Printf.printf "%s<>\n" (String.make ind ' ');
      List.iter (printtree (ind + 1)) l)

let rec requestion q (t: texttree) =
  match t with
  | Leaf t -> Leaf t
  | Node (l, Some r) ->
     Node (List.map (requestion (r.question @ q)) l,
           Some {r with question = (r.question @ q)})
  | Node (l, None) -> Node (List.map (requestion q) l, None)

(** Generate an exam from a list of items. *)
let gen (f: item list) : (text * gen_rpt_item option) list =
  let rec gen_lines f txts q p c : texttree =
    match f with
    | [] -> rev_tree txts
    | (Text txt)::t ->
       ((* Printf.printf "%s\n%!"
          (String.concat "\n" txt); *)
        gen_lines t (cons_tree txt txts) q p c)
    | (Variants (ch, rand, vars))::t ->
       let inds = choose (List.length vars) ch rand in
       let res =
         List.map
           (fun i ->
             let (varname, text) = List.nth vars i in
             gen_lines text
               (Node ([], Some {question = q; path = (c, i)::p;
                                label = varname}))
               q
               ((c, i)::p) 0) (*
             (match gen_lines text (Node ([], Some {question = q;
                                                    path = p;
                                      )) q ((c, i)::p) 0 with
              | Leaf t ->
                 Node ([Leaf t], Some {question = q;
                                       path = (c, i)::p;
                                       label = varname})
              | Node (l, None) ->
                 Node (l, Some {question = q;
                                path = (c, i)::p;
                                label = varname})
              | Node (l, Some r) ->
                 Node (l, Some { question = q;
                                 path = (c,i)::r.path;
                                 label = varname}))) *)
           inds
       in
       gen_lines t (revapp_tree res txts) q p (c + 1)
    | (Question (q', rand, items))::t ->
       match gen_lines items (Node ([], Some {question = q'; path = p;
                                              label = None})) q' [] 0 with
         Node (items', r) ->
         let items' =
           if rand then
             let len = List.length items' in
             let inds = choose len len true in
             List.map (List.nth items') inds
           else
             items'
         in
         let renumber_q_by q n =
           match q with
           | [] -> []
           | (nt, i)::t -> (nt, i + n)::t
         in
         let renumber i e =
           match e with
           | Leaf t -> Node ([Leaf t],
                             Some {question = renumber_q_by q' i;
                                   path = p;
                                   label = None})
           | Node (l, None) ->
              Node (l, Some {question = renumber_q_by q' i;
                                   path = p;
                                   label = None})
           | Node (l, Some r) ->
              Node (l, Some {r with question = renumber_q_by r.question i})
         in
         let items' = List.mapi renumber items' in
         gen_lines t (revapp_tree items' txts) q p c
       | Leaf t -> Leaf t
  in
  let r = (gen_lines f (Node ([], Some {question = []; path = []; label = None})) [] [] 0)
  in
  let r = requestion [] r in
  (*   let _ = printtree 0 r in *)
  flatten r
