#!/usr/bin/env python3
"""Lists every English text the game shows, for translating.

Texts come from tr('...') calls in lib/ and the text fields of the config
files. Writes tool/i18n/en.json ({text: ""} sorted) and, with --check,
reports what each assets/i18n/<code>.json is missing or has extra, and
fails on placeholders ({n}) that don't match. Missing texts show in
English until translated.

    python3 tool/i18n/extract.py            # update tool/i18n/en.json
    python3 tool/i18n/extract.py --check    # check the translations
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
# Config fields shown to the player (anything else is an id or number).
TEXT_FIELDS = {'name', 'desc', 'title', 'text', 'completeText', 'lines', 'badge'}
SKIP_FILES = {'services.json'}  # handled below: only achievements/leaderboards

LIT = r"""(?:r?'(?:[^'\\\n]|\\.)*'|r?"(?:[^"\\\n]|\\.)*")"""
CALL = re.compile(r"\btr\(\s*((?:" + LIT + r"\s*)+)")


def unescape(lit):
    raw = lit.startswith('r')
    body = lit[2:-1] if raw else lit[1:-1]
    if raw:
        return body
    if '$' in body.replace('\\$', ''):
        raise ValueError(f'interpolation inside tr(): {lit}')
    return re.sub(r"\\(.)", lambda m: {'n': '\n', 't': '\t'}.get(m[1], m[1]), body)


def code_texts():
    out = {}
    for p in sorted((ROOT / 'lib').rglob('*.dart')):
        src = p.read_text()
        for m in CALL.finditer(src):
            parts = re.findall(LIT, m[1])
            text = ''.join(unescape(x) for x in parts)
            out.setdefault(text, f'{p.relative_to(ROOT)}')
    return out


def config_texts():
    out = {}

    def walk(o, f, key=None):
        if isinstance(o, dict):
            for k, v in o.items():
                walk(v, f, k)
        elif isinstance(o, list):
            for v in o:
                walk(v, f, key)
        elif isinstance(o, str) and key in TEXT_FIELDS and o.strip():
            out.setdefault(o, f)

    for p in sorted((ROOT / 'assets/config').glob('*.json')):
        j = json.loads(p.read_text())
        if p.name == 'services.json':
            j = {k: j.get(k) for k in ('achievements', 'leaderboards')}
        walk(j, p.name)
    return out


def all_texts():
    texts = config_texts()
    texts.update(code_texts())
    return texts


def placeholders(s):
    return sorted(re.findall(r'\{\w+\}', s))


def main():
    texts = all_texts()
    if '--check' not in sys.argv:
        path = ROOT / 'tool/i18n/en.json'
        path.write_text(json.dumps({t: '' for t in sorted(texts)}, ensure_ascii=False, indent=1) + '\n')
        print(f'{len(texts)} texts -> {path.relative_to(ROOT)}')
        return
    bad = 0
    for p in sorted((ROOT / 'assets/i18n').glob('*.json')):
        tr = json.loads(p.read_text())
        missing = [t for t in texts if not tr.get(t)]
        extra = [t for t in tr if t not in texts]
        wrong = [t for t in texts if tr.get(t) and placeholders(t) != placeholders(tr[t])]
        print(f'{p.name}: {len(texts) - len(missing)}/{len(texts)} translated, '
              f'{len(extra)} unused, {len(wrong)} placeholder mismatches')
        for t in missing[:5]: print('   missing:', t[:80])
        for t in extra[:5]: print('   unused:', t[:80])
        for t in wrong[:5]: print('   placeholders:', t[:60], '->', tr[t][:60])
        bad += len(wrong)
    # Missing texts just stay in English; wrong placeholders would show
    # "{n}" to players, so those fail.
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
