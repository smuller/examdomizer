(** Examdomizer
    2021, Stefan Muller

    Reading and display of numbered lists *)


type numtype = Arabic
             | LRoman
             | URoman
             | LLetter
             | ULetter

exception InvalidNum of string

let rec explode n s =
  if n >= String.length s then
    []
  else
    (String.get s n)::(explode (n + 1) s)

let from_roman s =
  let rec from_chars c =
    match c with
    | [] -> 0
    | 'i'::'v'::t -> 4 + (from_chars t)
    | 'i'::'x'::t -> 9 + (from_chars t)
    | 'x'::'l'::t -> 40 + (from_chars t)
    | 'x'::'c'::t -> 90 + (from_chars t)
    | 'c'::'d'::t -> 400 + (from_chars t)
    | 'c'::'m'::t -> 900 + (from_chars t)
    | 'i'::t -> 1 + (from_chars t)
    | 'v'::t -> 5 + (from_chars t)
    | 'x'::t -> 10 + (from_chars t)
    | 'l'::t -> 50 + (from_chars t)
    | 'c'::t -> 100 + (from_chars t)
    | 'd'::t -> 500 + (from_chars t)
    | 'm'::t -> 1000 + (from_chars t)
    | _ -> raise (Invalid_argument "from_roman")
  in
  from_chars (explode 0 s)

(** Read a list index and determine the type and number.
    Note: "i" will be read as lowercase Roman 1, not as the 9th letter *)
let from_example (s: string) =
  match int_of_string_opt s with
  | Some n -> (Arabic, n)
  | None ->
     (if String.length s = 1 then
        match String.get s 0 with
        | 'i' -> (LRoman, 1)
        | 'I' -> (URoman, 1)
        | c when c >= 'a' && c <= 'z' ->
           (LLetter, (Char.code c) - (Char.code 'a') + 1)
        | c when c >= 'A' && c <= 'Z' ->
           (ULetter, (Char.code c) - (Char.code 'A') + 1)
        | _ -> raise (InvalidNum s)
      else
        if String.get s 0 > 'a' && String.get s 0 < 'z' then
          (LRoman, from_roman s)
        else
          (URoman, from_roman (String.lowercase_ascii s)))

let repeat c n = String.make n c
let divmod m n = (m / n, m mod n)
let st c = String.make 1 c
let roman n =
  let ord i v x n =
    if n <= 0 then ""
    else if n < 4 then repeat i n
    else if n = 4 then (st i) ^ (st v)
    else if n = 5 then (st v)
    else if n < 9 then (st v) ^ (repeat i (n - 5))
    else (st i) ^ (st x)
  in
  if (n > 3999) || (n <= 0) then raise (Invalid_argument "roman")
  else
    let (m, n) = divmod n 1000 in
    let (c, n) = divmod n 100 in
    let (x, n) = divmod n 10 in
    (repeat 'm' m) ^ (ord 'c' 'd' 'm' c) ^ (ord 'x' 'l' 'c' x) ^
      (ord 'i' 'v' 'x' n)

(** Render a number *)
let render (nt, n) =
  match nt with
  | Arabic -> string_of_int n
  | LLetter -> String.make 1 (Char.chr (n + (Char.code 'a') - 1))
  | ULetter -> String.make 1 (Char.chr (n + (Char.code 'A') - 1))
  | LRoman -> roman n
  | URoman -> String.uppercase_ascii (roman n)
     
