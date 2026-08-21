#!/usr/bin/python3
"""
calendar_events.py: dump country's public holidays for a given year to JSON format.

Usage:
   calendar_events.py <ISO_COUNTRY_CODE> <YEAR> <OUTPUT_PATH>

Example:
   calendar_events.py IN 2026 ~/.cache/chillpill-shell/holidays_IN_2026.json

Output JSON shape:
   { "YYYY-M-D": "Holiday name", ... }   (month/day unpadded, no leading zeros)

Exit codes are:
   0  success
   1  bad arguments
   2  invalid/unsupported country code
   3  invalid year
   4  holidays package not installed
   5  failed to write output file
"""

import json, os, sys

def fail(code: int, message: str) -> None:
    print(f"calendar_events: {message}", file=sys.stderr)
    sys.exit(code)

try:
   import holidays
except ImportError:
   fail(4, "the 'holidays' package is not installed\n  run: pip install holidays --break-system-packages")

def main() -> None:
    if len(sys.argv) != 4:
        fail(1, f"expected 3 arguments, got {len(sys.argv) - 1}\n"
                 f"usage: calendar_events.py <COUNTRY_CODE> <YEAR> <OUTPUT_PATH>")

    country_code, year_str, output_path = sys.argv[1:4]
    output_path = os.path.expanduser(output_path)

    try:
        year = int(year_str)
    except ValueError:
        fail(3, f"'{year_str}' is not a valid year")

    try:
        country_holidays = holidays.country_holidays(country_code, years=year)
    except NotImplementedError:
        fail(2, f"'{country_code}' is not a supported country code")
    except KeyError:
        fail(2, f"'{country_code}' is not a recognized country code")

    result = {
        f"{date.year}-{date.month}-{date.day}": name
        for date, name in sorted(country_holidays.items())
    }

    try:
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        # write to a temp file then rename, so a crash mid-write never
        # leaves a truncated/corrupt cache file behind
        tmp_path = output_path + ".tmp"
        with open(tmp_path, "w") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, output_path)
    except OSError as e:
        fail(5, f"failed to write '{output_path}': {e}")

    print(f"country_events: wrote {len(result)} holidays to {output_path}")


if __name__ == "__main__":
    main()
