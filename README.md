# examdomizer
Generation of exams from a template with a pool of questions

## Installing
### Dependences
OCaml >= 4.06.0

To build, just run `make`.

## Usage

### Overview and File Structure

Examdomizer produces multiple versions of a file, selecting blocks of text from a number of
alternatives, called _variants_, in a template file given as input. It may be used to generate
variations of an exam for different students by selecting from a pool of questions, where the
variants are the possible questions. Variants can also be nested so, for example, within each
question selected to appear on an exam, Examdomizer can select from a pool of multiple choice
answers to include. Finally, when multiple variants are selected, examdomizer can randomize the
order.

A file has three structural elements embedded in text.

* _Variants_ are the main building blocks of files. A variant is a block
  of text, possibly including questions (and more variants) nested inside it.
  The selection and randomization acts on variants.
* Variants are grouped into _variant collections_. A variant collection
  contains some number of variants, of which a specified number will be
  selected. The selected variants may also be randomly reordered.
* Variant collections are grouped into _questions_. A question collects all of
  the selected variants from its variant collections, and numbers them
  consecutively for the purposes of logging and identifying which students
  have particular variants. You can also randomize the order of all selected
  variants within a question.

### Template file

Examdomizer takes as input a specially annotated plain text or LaTeX file
(technically, other formats can be used as well, but the annotations are
designed to appear to LaTeX as comments).

Special lines beginning with `%%>` (possibly preceded by whitespace) denote the beginning and
end of variants, collections and questions. The syntax is described below.

    %%> begin question [randomize order] [numbering]
    %%> end question

These lines begin or end a question. If `randomize order` is selected, variants selected from
within the question will be randomly permuted. You can also optionally specify a question
numbering. This is a sequence of numbers separated with spaces, giving the
(sub)question number that will be assigned to the first variant to appear inside the question.
The remaining variants will be numbered consecutively. For example, specifying `2 a` would cause
the first variant to be numbered 2a, the second to be numbered 2b, and so on.  Numbers can be:

* numerals
* lowercase (i, ii, iii) or uppercase (I, II, III) roman numerals
* lowercase (a, b, c) or uppercase (A, B, C) letters

Note that the strings "i" and "I" will be interpreted as roman numerals rather than letters.

Text may appear within a question but outside variant collections. Note, however, that this
text will be randomly rearranged if `randomize order` is selected.

    %%> begin variants N [randomize order]
    %%> end variants

These lines begin or end a collection of variants, from which N will be selected. As with
questions, the selected variants can be randomly permuted. Note that specifying `randomize order`
at the level of the question can mix up variants between multiple collections, while
specifying it at the level of the collection only permutes variants in that collection.

Text appearing inside a variant collection but outside any variant is ignored by Examdomizer
and can be used to add comments that appear when compiling the template file but not in
any generated exam.

    %%> begin variant [name]
    %%> end variant

These lines begin and end a variant. The variant can optionally be given a unique name to
identify it. Ending variants is not necessary: the variant is assumed to end at the start of
the next variant or the end of the collection.

#### Example

Suppose we want to select 4 multiple choice answers from a pool containing 6 incorrect answers
and 1 correct answer. The correct answer must always be included, so we place that in its own
collection and specify that 1 variant must be chosen. We place the incorrect answers in
another collection and specify that 3 should be chosen. Finally, we specify `randomize order'
on the question to randomize the order, permuting all of the selected answers, including
the correct one.

    %%> begin question randomize order a
    %%> begin variants 1
    The correct answer needs to be in its own collection to ensure it's
    always picked.
    %%> begin variant 1corr
    \item The correct answer
    %%> end variant
    We can end the variant early and have more non-included text.
    %%> end variants
    %%> begin variants 3
    %%> begin variant 1inc1
    \item Incorrect answer 1
    %%> begin variant 2inc1
    \item Incorrect answer 2
    %%> begin variant 3inc1
    \item Incorrect answer 3
    %%> begin variant 4inc1
    \item Incorrect answer 4
    %%> begin variant 5inc1
    \item Incorrect answer 5
    %%> begin variant 6inc1
    \item Incorrect answer 6
    %%> end variants
    %%> end question

### Modes

Examdomizer has 3 main modes of operation:

* Generate one random exam from a template
* Take a class list in .csv form and generate an exam for each student. The output files are
  placed in a directory named with the student ID.
* Do not generate any exams, but output which students have a given variant(s) on their exam.

### Randomization

It is recommended that, when generating exams for a class, you generate exams deterministically
so that exams can be regenerated if necessary and each student will receive the same exam
each time. Before generating each exam, the PRNG is seeded with the hash of the concatenation
of some combination of the following three strings:

* The student's student ID
* The name of the input file
* An additional string given on the command line.

Command-line flags determine which of these strings, if any, are used (if only generating one
exam, the student ID cannot be used). If none are used, the PRNG is initialized once at the
start of execution with a platform-dependent random seed.

### Command-line options

    ./examdomize [OPTIONS] INPUTFILE

INPUTFILE is the template file to use as input. The options are described below:

    -s <file>
    --students <file>

Specify a CSV file to use as the class list. The first row of the file must have the same
format as the rest of the rows and identify three columns as `first`, `last` and `id`.

    -t
    -tf
    -ta <string>

If any of these flags is given (`-t` can only be used in conjunction with `-s`), generation is
deterministic. Flag `-t` turns on using the student ID as a seed. Flag `-tf` turns on using
the filename, and flag `-ta` allows the user to specify an additional string to use.

    -w <variant name>
    --whohas <variant name>
    -w <variant name>/<question number>
    --whohas <variant name>/<question number>

Operate in "whohas" mode: rather than generate exams, Examdomizer will output a list of
students who would receive the specified variant (the variant must be given a unique ID as
specified above). It will also specify, for each student, the question number under which this
variant appears, if the variant is in a numbered question. 
If a question number is provided after a slash (e.g. "var1/2a"), it will
only include students for whom the variant "var1" appears as question "2a".
It makes the most sense to use this
when generation is deterministic, using one or more of the flags above.
This option can be used multiple times to output only students matching *all* of the conditions.

    -b <directory>
    --basedir <directory>
    -o <filename>
    --outfile <filename>

Specify the base directory and output file name. If using `-s`, each file will be output in a
separate directory under the base directory.

    -d
    --debug

Debug mode: doesn't actually write files.

    -l
    --log

Log generated files and variants to standard out (especially useful in debug mode).
