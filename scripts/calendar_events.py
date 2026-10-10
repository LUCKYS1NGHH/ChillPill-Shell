#!/usr/bin/python3
"""
calendar_events.py: dump a country's holidays for a given year to JSON.

Usage:
   calendar_events.py <ISO_COUNTRY_CODE> <YEAR> <OUTPUT_PATH> [--all]
                      [--categories public,optional] [--subdiv MH]

Example:
   calendar_events.py IN 2026 ~/.cache/chillpill-shell/holidays_IN_2026.json --all

Output JSON shape:
   { "YYYY-M-D": "Holiday name", ... }   (month/day unpadded)
   Multiple holidays on one date are joined with "; ".

Exit codes:
   0  success
   1  bad arguments
   2  invalid/unsupported country code
   3  invalid year
   4  holidays package not installed
   5  failed to write output file
   6  invalid/unsupported subdivision or category
"""

import argparse, json, os, sys


def fail(code: int, message: str) -> None:
    print(f"calendar_events: {message}", file=sys.stderr)
    sys.exit(code)


try:
    import holidays
except ImportError:
    fail(4, "the 'holidays' package is not installed\n"
            "  run: pip install holidays --break-system-packages")


class Parser(argparse.ArgumentParser):
    def error(self, message):  # keep exit code 1 for bad args
        fail(1, message)


def main() -> None:
    p = Parser(prog="calendar_events.py")
    p.add_argument("country")
    p.add_argument("year")
    p.add_argument("output")
    p.add_argument("--all", action="store_true",
                   help="include every category the country supports")
    p.add_argument("--categories",
                   help="comma-separated categories, e.g. public,optional")
    p.add_argument("--subdiv", help="state/province code, e.g. MH")
    args = p.parse_args()

    code = args.country.upper()
    output_path = os.path.expanduser(args.output)

    try:
        year = int(args.year)
    except ValueError:
        fail(3, f"'{args.year}' is not a valid year")

    # probe: validates country and tells us what it supports
    try:
        probe = holidays.country_holidays(code)
    except (NotImplementedError, KeyError):
        fail(2, f"'{code}' is not a supported country code")

    supported = tuple(probe.supported_categories)
    if args.all:
        categories = supported
    elif args.categories:
        categories = tuple(c.strip().lower() for c in args.categories.split(","))
        bad = [c for c in categories if c not in supported]
        if bad:
            fail(6, f"unsupported for {code}: {', '.join(bad)} "
                    f"(supported: {', '.join(supported)})")
    else:
        categories = ("public",)

    try:
        country_holidays = holidays.country_holidays(
            code, years=year, categories=categories, subdiv=args.subdiv)
    except NotImplementedError:
        fail(6, f"unknown subdivision '{args.subdiv}' for {code} "
                f"(valid: {', '.join(probe.subdivisions) or 'none'})")

    result = {
        f"{d.year}-{d.month}-{d.day}": name
        for d, name in sorted(country_holidays.items())
    }

    try:
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        tmp_path = output_path + ".tmp"
        with open(tmp_path, "w") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, output_path)
    except OSError as e:
        fail(5, f"failed to write '{output_path}': {e}")

    print(f"calendar_events: wrote {len(result)} holidays "
          f"({', '.join(categories)}) to {output_path}")


if __name__ == "__main__":
    main()
