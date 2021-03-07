(** Examdomizer
    Copyright (C) 2021 Stefan Muller

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
 **)

open Readcsv

type mode = Gen | Whohas of string

let mode = ref Gen
let csv = ref ""
let det = ref false
let detfile = ref false
let detstring = ref ""
let infile = ref ""
let outdir = ref ""
let outfile = ref ""
let debug = ref false
let log = ref false

open Arg
let _ = parse
          [("-s", Set_string csv, "CSV file with class list");
           ("--students", Set_string csv, "CSV file with class list");
           ("-t", Set det,
            "Generation is deterministic based on hash of student ID");
           ("-tf", Set det,
            "Generation is deterministic based on hash of student ID and input file name");
           ("-ta", Set_string detstring,
            "Additional string to use in hash for random seed");
           ("-w", String (fun s ->
                      mode := Whohas s),
            "Do not generate files but output which students have the specified variant.");
           ("--whohas", String (fun s ->
                      mode := Whohas s),
            "Do not generate files but output which students have the specified variant.");
             ("-b", Set_string outdir, "Output base directory");
             ("--basedir", Set_string outdir, "Output base directory");
             ("-o", Set_string outfile, "Output file name, <base>-out.<ext> by default.");
             ("--outfile", Set_string outfile, "Output file name, <base>-out.<ext> by default.");
             ("-d", Set debug, "Do not write files, use with -l or --log");
             ("--debug", Set debug, "Do not write files, use with -l or --log");
             ("-l", Set log, "Log generated variants to stdout");
             ("--log", Set log, "Log generated variants to stdout");
          ]
          (fun s -> infile := s)
          "./examdomize [options] INPUTFILE"

let gen_file items outfile =
  let out = Gen.gen items in
  Writetex.write
    outfile
    !debug
    out
    (if !log then Some stdout else None)

let inbase = if !infile = "" then
               (Printf.eprintf "ERROR: input file is required.\n";
                exit 1)
             else
               Filename.basename (!infile)
  
let items = Readtex.readfile !infile

let rec findopt f l =
  match l with
  | [] -> None
  | x::t -> (match f x with
             | Some r -> Some r
             | None -> findopt f t)
          
let has label items =
  findopt (fun (_, r) ->
      match r with
      | None -> None
      | Some {Gen.question = q; path = _; label = Some l } ->
         if label = l then Some q else None
      | Some _ -> None)
    items

let setseed id file =
  let _ = if !det && String.length id = 0 then
            (Printf.printf "ERROR: -t set without class list\n";
             exit 1)
          else ()
  in
  let seedstring = (if !det || !detfile then id else "")
                   ^ (if !detfile then file else "")
                   ^ !detstring
  in
  if String.length seedstring > 0 then
    Random.init (Hashtbl.hash seedstring)
  else
    ()


let outbase = if !outfile = "" then
                (Filename.remove_extension inbase)
                ^ "-out"
                ^ (Filename.extension inbase)
              else Filename.basename (!outfile)
  
let _ = if (not !det) && (not !detfile) && (String.length !detstring = 0)
        then Random.self_init ()
        else ()
  
let _ =
  match !mode with
  | Whohas s ->
     if !csv = "" then
       (Printf.printf "-s or --students option is required for -whohas.\n";
        exit 1)
     else
       let students = Readcsv.read (!csv)
       in
       List.iter
         (fun st ->
           let _ = setseed st.id inbase
           in
           let sitems = Gen.gen items in
           match has s sitems with
           | Some q ->
              Printf.printf "%s\t%s\t%s\t%s\n" st.last st.first st.id
                (Gen.print_q q)
           | None ->
             ())
         students
  | Gen ->
     if !csv = "" then
       (setseed "" inbase;
        gen_file items (Filename.concat (!outdir) outbase))
     else
       let students = Readcsv.read (!csv)
                    
       in
       List.iter
         (fun s ->
           let _ = setseed s.id inbase
           in
           let dir = !outdir ^ Filename.dir_sep ^ s.id in
           let _ = if not !debug then
                     try Unix.mkdir dir 0o751
                     with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
                   else ()
           in
           gen_file items (Filename.concat dir outbase))
         students
