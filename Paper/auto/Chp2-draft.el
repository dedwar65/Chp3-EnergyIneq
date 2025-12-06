(TeX-add-style-hook
 "Chp2-draft"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-package-options
                     '(("placeins" "section")))
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "path")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "url")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "nolinkurl")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "hyperbaseurl")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "hyperimage")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "href")
   (add-to-list 'LaTeX-verbatim-macros-with-delims-local "path")
   (TeX-run-style-hooks
    "latex2e"
    "Subfiles/packages"
    "Subfiles/results"
    "article"
    "art10"
    "subfiles"
    "footnote"
    "lipsum"
    "graphicx"
    "float"
    "placeins"
    "afterpage"
    "caption"
    "subcaption"
    "booktabs"
    "threeparttable"
    "multirow"
    "geometry"
    "pdflscape"))
 :latex)

