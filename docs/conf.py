# Configuration file for Sphinx documentation builder
# https://www.sphinx-doc.org/en/master/usage/configuration.html

project = "haven"
author = "Vincent Huybrechts"
copyright = "2026, Vincent Huybrechts"
release = "1.0.0"

extensions = [
    "myst_parser",          # Markdown (.md) support
]

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

# MyST settings — enable useful extensions
myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "tasklist",
]

# HTML output
html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]
html_title = "haven"

# Source file types
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
