(** Examdomizer
    2021, Stefan Muller

    Write output files and logs *)

open Gen

module SSet = Set.Make(struct type t = string
                              let compare = String.compare
                       end)

let write (filename: string)
      (debug: bool)
      (output: (Readtex.text * gen_rpt_item option) list)
      (log: out_channel option) =
  let log_enter (i: gen_rpt_item option) (logged: SSet.t) : string * SSet.t =
    match i with
    | None -> ("", logged)
    | Some {question; path; label = Some l} ->
       if SSet.mem l logged then ("", logged)
       else
         (Printf.sprintf "%s as %s\n" l (print_q question),
          SSet.add l logged)
    | Some _ -> ("", logged)
  in
  let ochan = if not debug then
               Some (open_out filename)
             else None
  in
  let rec writelines outp logged =
    match (outp, ochan, log) with
    | ([], Some o, _) -> close_out o
    | ([], None, _) -> ()
    | ((l, r)::t, Some o, None) ->
       (output_string o ((String.concat "\n" l) ^ "\n");
        writelines t logged)
    | ((l, r)::t, None, Some log) ->
       let (s, log') = log_enter r logged in
       (output_string log s;
        writelines t log')
    | ((l, r)::t, Some o, Some log) ->
       let (s, log') = log_enter r logged in
       (output_string o ((String.concat "\n" l) ^ "\n");
        output_string log s;
        writelines t log')
    | ((l, r)::t, None, None) ->
       (Printf.printf "WARNING: logging turned off in debug mode, nothing will be output.\n";
        ())
  in
  (match log with
   | Some logchan -> output_string logchan ("writing " ^ filename ^ "\n")
   | None -> ());
  writelines output SSet.empty
              
      
