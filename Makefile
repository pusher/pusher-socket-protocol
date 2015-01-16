
protocol.html: protocol.adoc
	plantuml -o images/ -tsvg protocol.adoc
	asciidoctor protocol.adoc
