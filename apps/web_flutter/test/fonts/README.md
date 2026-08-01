# Golden CJK fonts

These files are test-only Chinese glyph subsets. They are loaded by
`test/flutter_test_config.dart` and are intentionally not declared in
`pubspec.yaml`, so they do not increase the production Web bundle.

- Body text uses Noto Sans SC at weights 400 and 700.
- Monospace test styles reuse Noto Sans SC so Markdown source and code-adjacent
  Chinese text exercise real glyphs instead of Ahem placeholders.
- Editorial headings use Noto Serif SC at weight 700.
- The subset corpus is the unique characters found in `lib/**/*.dart` and
  `test/**/*.dart`, plus renderer-generated list markers.
- Source fonts come from the Google Fonts CSS API and are reduced with
  FontTools `pyftsubset`.
- The font software is distributed under the SIL Open Font License in
  `OFL.txt`.

Run `tool/update_golden_fonts.sh` after adding CJK text that is not covered by
the current subset, then regenerate Golden images.
