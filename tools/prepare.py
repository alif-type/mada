#!/usr/bin/env python
# encoding: utf-8

from fontTools.misc.py23 import *

import argparse
import math
import os
import unicodedata

from collections import Counter
from datetime import datetime
from operator import attrgetter

from ufoLib2 import Font
from fontTools.feaLib import ast, parser

POSTSCRIPT_NAMES = "public.postscriptNames"

def generateStyleSets(ufo):
    """Generates ss01 feature which is used to move the final Yeh down so that
    it does not raise above the connecting part of other glyphs, as it does by
    default. We calculate the height difference between Yeh and Tatweel and set
    the feature accordingly."""

    tatweel = ufo["kashida-ar"].getBounds(ufo.layers.defaultLayer)
    yeh = ufo["alefMaksura-ar.fina"].getBounds(ufo.layers.defaultLayer)
    delta = tatweel.yMax - yeh.yMax

    fea = """
feature ss01 {
    pos alefMaksura-ar.fina <0 %s 0 0>;
} ss01;
""" % int(delta)

    return fea

def merge(args):
    """Merges Arabic and Latin fonts together, and messages the combined font a
    bit. Returns the combined font."""

    ufo = Font(args.arabicfile)

    latin = Font(args.latinfile)

    # Save original glyph order, used below.
    glyphOrder = ufo.glyphOrder + latin.glyphOrder

    # Merge Arabic and Latin features, making sure languagesystem statements
    # come first.
    features = ufo.features
    langsys = []
    statements = []
    ss = 0
    for font in (ufo, latin):
        featurefile = os.path.join(font.path, "features.fea")
        fea = parser.Parser(featurefile, font.glyphOrder).parse()
        for s in fea.statements:
            if isinstance(s, ast.LanguageSystemStatement):
                langsys.append(s)
            else:
                name =  getattr(s, "name", "")
                if name in ("aalt", "kern", "mark", "mkmk"):
                    # We will regenerate kern, mark and mkmk, aalt is useless.
                    continue
                if isinstance(s, ast.MarkClassDefinition):
                    # These will be regenerated as well.
                    continue
                if isinstance(s, ast.TableBlock):
                    # Drop tables in fea, we don’t want them.
                    continue
                if isinstance(s, ast.FeatureBlock) and name.startswith("ss"):
                    if font.path == args.arabicfile:
                        # Find max ssXX feature in Arabic font.
                        ss = max(ss, int(s.name[2:]))
                    else:
                        # Increment Latin ssXX features.
                        s.name = f"ss{int(s.name[2:]) + ss:02}"
                statements.append(s)

    # Make sure DFLT is the first.
    langsys = sorted(langsys, key=attrgetter("script"))
    fea.statements = langsys + statements
    features.text = fea.asFea()

    features.text += generateStyleSets(ufo)

    # Source Sans Pro has different advance widths for space and NBSP
    # glyphs, fix it.
    latin["nbspace"].width = latin["space"].width

    # Set Latin production names
    ufo.lib[POSTSCRIPT_NAMES].update(latin.lib[POSTSCRIPT_NAMES])

    # Copy Latin glyphs.
    for name in latin.glyphOrder:
        glyph = latin[name]
        # Remove anchors from spacing marks, otherwise ufo2ft will give them
        # mark glyph class which will cause HarfBuzz to zero their width.
        if glyph.unicode and unicodedata.category(unichr(glyph.unicode)) in ("Sk", "Lm"):
            glyph.anchors = []
        # Add Arabic anchors to the dotted circle, we use an offset of 100
        # units because the Latin anchors are too close to the glyph.
        offset = 100
        if glyph.unicode == 0x25CC:
            for anchor in glyph.anchors:
                if anchor.name == "aboveLC":
                    glyph.appendAnchor(dict(name="markAbove", x=anchor.x, y=anchor.y + offset))
                    glyph.appendAnchor(dict(name="hamzaAbove", x=anchor.x, y=anchor.y + offset))
                if anchor.name == "belowLC":
                    glyph.appendAnchor(dict(name="markBelow", x=anchor.x, y=anchor.y - offset))
                    glyph.appendAnchor(dict(name="hamzaBelow", x=anchor.x, y=anchor.y - offset))
        # Break loudly if we have duplicated glyph in Latin and Arabic.
        # TODO should check duplicated Unicode values as well
        assert glyph.name not in ufo, glyph.name
        ufo.addGlyph(glyph)
        ufo.glyphOrder += [glyph.name]

    # Copy kerning and groups.
    ufo.groups.update(latin.groups)
    ufo.kerning.update(latin.kerning)

    # We don’t set these in the Arabic font, so we just copy the Latin’s.
    for attr in ("xHeight", "capHeight"):
        value = getattr(latin.info, attr)
        if value is not None:
            setattr(ufo.info, attr, getattr(latin.info, attr))

    # Make sure we don’t have glyphs with the same unicode value
    unicodes = []
    for glyph in ufo:
        unicodes.extend(glyph.unicodes)
    duplicates = set([u for u in unicodes if unicodes.count(u) > 1])
    assert len(duplicates) == 0, "Duplicate unicodes: %s " % (["%04X" % d for d in duplicates])

    # Make sure we have a fixed glyph order by using the original Arabic and
    # Latin glyph order, not whatever we end up with after adding glyphs.
    ufo.glyphOrder = sorted(ufo.glyphOrder, key=glyphOrder.index)

    return ufo

def decomposeFlippedComponents(ufo):
    from fontTools.pens.transformPen import TransformPointPen
    for glyph in ufo:
        for component in list(glyph.components):
            xx, xy, yx, yy = component.transformation[:4]
            if xx*yy - xy*yx < 0:
                pen = TransformPointPen(glyph.getPointPen(), component.transformation)
                ufo[component.baseGlyph].drawPoints(pen)
                glyph.removeComponent(component)

def setInfo(info, version):
    """Sets various font metadata fields."""

    info.versionMajor, info.versionMinor = map(int, version.split("."))

    copyright = u"Copyright © 2015-%s The Mada Project Authors, with Reserved Font Name “Source”." % datetime.now().year

    info.copyright = copyright

def build(args):
    ufo = merge(args)
    setInfo(ufo.info, args.version)
    decomposeFlippedComponents(ufo)

    return ufo

def main():
    parser = argparse.ArgumentParser(description="Build Mada fonts.")
    parser.add_argument("arabicfile", metavar="FILE", help="input font to process")
    parser.add_argument("latinfile", metavar="FILE", help="input font to process")
    parser.add_argument("--out-file", metavar="FILE", help="output font to write", required=True)
    parser.add_argument("--version", metavar="version", help="version number", required=True)

    args = parser.parse_args()

    ufo = build(args)
    ufo.save(args.out_file)

if __name__ == "__main__":
    main()
