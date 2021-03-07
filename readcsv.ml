(** Examdomizer
    2021, Stefan Muller

    Read a class list in CSV format *)

type student = { last  : string;
                 first : string;
                 id    : string}

let rec lstrip_junk (s: string) =
  if String.length s = 0 then s
  else
    let c = String.get s 0 in
    if c >= ' ' && c <= 'z' then s
    else lstrip_junk (String.sub s 1 ((String.length s) - 1))

let strip (s: string) =
  let s = String.trim (lstrip_junk s) in
  if String.length s < 2 then s
  else
    if String.get s 0 = '\"' then
      String.sub s 1 ((String.length s) - 2)
    else
      s

exception CSVError of string

(** Read a csv file f.
 ** The first line must be a key marking columns "first", "last" and "id".
 ** Raises CSVError if not. *)
let read (f: string) =
  let readkey s =
    let tabs = String.split_on_char ',' s in
    let f (l, f, i, n) s =
      match strip s with
        "last" -> (Some n, f, i, n + 1)
      | "first" -> (l, Some n, i, n + 1)
      | "id" -> (l, f, Some n, n + 1)
      | _ -> (l, f, i, n + 1)
    in
    match List.fold_left f (None, None, None, 0) tabs with
    | (Some l, Some f, Some i, _) -> (l, f, i)
    | _ -> raise (CSVError "some columns not labeled")
  in
  let chan = open_in f in
  let key = input_line chan in
  let (l, f, i) = readkey key in
  let rec readrow students =
    try
      let row = input_line chan in
      let tabs = List.map strip (String.split_on_char ',' row) in
      let s = { last = List.nth tabs l;
                first = List.nth tabs f;
                id = List.nth tabs i}
      in
      readrow (s::students)
      with
        End_of_file -> List.rev students
  in
  let students = readrow [] in
  let _ = close_in chan in
  students
    
