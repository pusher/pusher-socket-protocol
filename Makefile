
README.html: README.adoc
	plantuml -o images/ -tsvg README.adoc
	asciidoctor README.adoc
