(TeX-add-style-hook
 "results"
 (lambda ()
   (TeX-run-style-hooks
    "../Tables/trust_income_rv557"
    "../Tables/trust_income_pca"
    "../Tables/trust_rv557_returns"
    "../Tables/trust_pca_returns"
    "../Tables/baseline_pooled"
    "../Tables/shares_interacted"
    "../Tables/fixed_effects"
    "../Tables/trust_rv557_returns_avg"
    "../Tables/trust_pca_returns_avg"
    "../Tables/trust_correlation_2020"
    "../Tables/trust_rv557_spec5"
    "../Tables/trust_pca_spec5"
    "../Tables/trust_pca2_spec5"
    "../Tables/const_trust_rv557"
    "../Tables/const_trust_rv560"
    "../Tables/const_trust_rv561"
    "../Tables/const_trust_rv562")
   (LaTeX-add-labels
    "sec:results"))
 :latex)

