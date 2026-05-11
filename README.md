# Docs Template

A starter repository for small LaTeX-based documentation projects.

## Structure

- `manual_style.sty` provides the shared document styling.
- `example.tex` is a minimal source document to copy or rename.
- `render_all_pdf.sh` compiles every top-level `.tex` file into `pdf/`.
- `build/` contains temporary LaTeX build files and is ignored by Git.
- `pdf/` contains rendered PDFs and is ignored by Git except for `.gitkeep`.

## Usage

Create or edit one or more top-level `.tex` files, then run:

```sh
./render_all_pdf.sh
```

Force a clean rebuild:

```sh
./render_all_pdf.sh --force
```

Adjust page padding for a one-off render:

```sh
./render_all_pdf.sh --left-padding -6pt --right-padding +12pt
```

The script requires `latexmk` and a LaTeX installation with the packages used by `manual_style.sty`.

