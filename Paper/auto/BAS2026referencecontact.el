(TeX-add-style-hook
 "BAS2026referencecontact"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-package-options
                     '(("placeins" "section")))
   (TeX-run-style-hooks
    "latex2e"
    "article"
    "art10"
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

