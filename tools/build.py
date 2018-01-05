#!/usr/bin/env python
# encoding: utf-8

import argparse
import os

from fontmake.font_project import FontProject
from mutatorMath.ufo.document import DesignSpaceDocumentReader

def epoch(args):
    reader = DesignSpaceDocumentReader(args.designspace, ufoVersion=3)
    paths = reader.getSourcePaths() + [args.designspace]
    # We want to check the original masters in the source not build directory.
    paths = [os.path.join(args.source, os.path.basename(p)) for p in paths]
    # Not all masters exist in the source directory.
    paths = [p for p in paths if os.path.exists(p)]
    epoch = max([os.stat(p).st_mtime for p in paths])

    return str(int(epoch))

def build(args):
    designspace = os.path.join(args.build, args.designspace)

    os.environ["SOURCE_DATE_EPOCH"] = epoch(args)

    project = FontProject(verbose="WARNING")
    if args.ufo:
        project.run_from_ufos([args.ufo],
            output=args.output, remove_overlaps=False, reverse_direction=False,
            subroutinize=True, autohint="")
    else:
        project.run_from_designspace(designspace,
            output=args.output, subroutinize=True, autohint="")

def main():
    parser = argparse.ArgumentParser(description="Build Mada fonts.")
    parser.add_argument("--source", metavar="DIR", help="Source directory", required=True)
    parser.add_argument("--build", metavar="DIR", help="Build directory", required=True)
    parser.add_argument("--designspace", metavar="FILE", help="DesignSpace file", required=True)
    parser.add_argument("--ufo", metavar="FONT", help="UFO source to process")
    parser.add_argument("--output", metavar="OUTPUT", help="Output format", required=True)
    parser.add_argument("--release", help="Build with optimizations for release", action="store_true")

    args = parser.parse_args()

    build(args)

if __name__ == "__main__":
    main()
