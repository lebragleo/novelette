# README for NoveletteSerif, NoveletteSans, NoveletteDeco fonts

These fonts are included with the Novelette document class for LuaLaTeX,
by Terry Lebragleo.

You may use them with other software. However, you will not see the same performance
as obtained in Novelette.

The Sans and Deco fonts do not have useful glyphs for monetary, math, or other special symbols.
This is intentional. As a result, these fonts are not suitable for general-purpose usage.

If you modify the fonts, and your font editor can assign UniqueID, be sure to remove the
prefix tlbrnvt: from the ID. In FontForge, this metadata is in Element > Font Info > TTF Names.

Novelette requires that each glyph not rise above 840 grid units, or descend below
-230 grid units. Only exception is the "bar.bad" character, which serves a special purpose
only in Novelette. This is with PostScript (cubic) outlines, at 1000 units per em.

The Serif fonts do not have bold. Novelette is designed for popular fiction, which never uses
bold in running text. The Sans and Deco fonts are designed for displays, and offer glyphs
with different styles.

Modern digital printing, especially for print-on-demand, produces sharper characters than
those produced by traditional offset print. As a result, glyphs with narrow stems will print
lighter than expected. Novelette fonts are designed with this in mind, avoiding shapes
that would not print well. If you modify the fonts, observe the stem weights.
