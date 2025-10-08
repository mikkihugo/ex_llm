# Template Meta Parser

Loads and normalizes quality template metadata from the `priv/code_quality_templates` directory.

This crate mirrors the dependency parser design by exposing a provider-based interface. The default filesystem provider reads the `TEMPLATE_MANIFEST.json` file and each referenced template document, returning structured metadata for downstream validation and export pipelines.
