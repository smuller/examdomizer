all: numtypes.ml readcsv.ml readtex.ml gen.ml writetex.ml main.ml
	ocamlc -g -o examdomize unix.cma numtypes.ml readcsv.ml readtex.ml gen.ml writetex.ml main.ml

clean:
	rm *.cmo
	rm *.cmi
	rm examdomize
