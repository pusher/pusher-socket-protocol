# The Pusher Protocol Docs

A new version of the Pusher Protocol docs.

*This is likely to be a temporary project and will be superceded when the Pusher
documentation is all updated in the near future.*

## Prerequisites

### PlantUML

[PlantUML](http://plantuml.sourceforge.net/) is required for building the sequence
diagrams in the document.

The easiest way to install PlantUML on Mac is using [Homebrew](http://brew.sh/).

```
brew install plantuml
```

### Ruby

Ruby is required in order to install the [asciidoctor gem](https://rubygems.org/gems/asciidoctor)
and to build the protocol documentation.

## Editing the Docs

The docs are written in [AsciiDoc](http://asciidoctor.org/docs/what-is-asciidoc/)
and generated using [Asciidoctor](http://asciidoctor.org/).

To edit the docs simply edit the `README.adoc` using the AsciiDoc syntax.

## Building the Docs

The docs are built using a simple make command. The `MakeFile` first creates
images for the diagrams defined in `README.adoc` and then generates the HTML
document using [Asciidoctor](http://asciidoctor.org/).

From the working directory execute:

```
make
```

This will create a `README.html` file. The `index.html` file is a symbolic link
to `README.html`.
