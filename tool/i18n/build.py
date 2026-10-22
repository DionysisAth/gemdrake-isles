#!/usr/bin/env python3
"""Builds assets/i18n/<code>.json from a numbered translation list.

The list has one line per text of tool/i18n/en.json, in the same order:
`<number>|<translation>`, with line breaks written as \\n.

    python3 tool/i18n/build.py el path/to/el.txt
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main(code, src):
    en = sorted(json.loads((ROOT / 'tool/i18n/en.json').read_text()))
    out, errors = {}, []
    for line in pathlib.Path(src).read_text().splitlines():
        if not line.strip():
            continue
        num, _, text = line.partition('|')
        i = int(num)
        text = text.replace('\\n', '\n').strip()
        if code == 'fr':
            # French puts a space before ! ? : ; that must not break.
            text = re.sub(r' ([!?:;])', '\u00a0\\1', text)
        if i >= len(en):
            errors.append(f'{i}: no such text'); continue
        key = en[i]
        if sorted(re.findall(r'\{\w+\}', key)) != sorted(re.findall(r'\{\w+\}', text)):
            errors.append(f'{i}: placeholders differ: {key!r} -> {text!r}')
        if key.count('\n') != text.count('\n'):
            errors.append(f'{i}: line breaks differ')
        out[key] = text
    missing = [f'{i}: {t}' for i, t in enumerate(en) if t not in out]
    for e in errors + [f'missing {m}' for m in missing]:
        print(e)
    if errors or missing:
        sys.exit(1)
    path = ROOT / f'assets/i18n/{code}.json'
    path.write_text(json.dumps(out, ensure_ascii=False, indent=1, sort_keys=True) + '\n')
    print(f'{code}: {len(out)} texts -> {path.relative_to(ROOT)}')


if __name__ == '__main__':
    main(*sys.argv[1:3])
