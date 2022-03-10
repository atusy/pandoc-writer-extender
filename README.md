# Pandoc writer extender

This project provides `writer.lua` which is capable of inheriting variety of output formats.

This script enable extending existing internal writers by partially modifying the functions in the script.

The default output format is html.

```sh
> echo '***foo*** & bar' | pandoc -t writer.lua
<p><strong><em>foo</em></strong> &amp; <sup>bar</sup></p>
```

Change output format by specifying `custom-writer-format` metadata.

``` sh
> echo '***foo*** & ^bar^' | pandoc -t writer.lua --metadata=custom-writer-format:latex
\textbf{\emph{foo}} \& \textsuperscript{bar}
```

