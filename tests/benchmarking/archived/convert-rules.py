#!/usr/bin/env python3
"""Convert original bash rules to Option F, G (reuses YAML), and H formats.
Also generates 3x scaled versions for all options (B, D, E, F, H)."""
import re
import os
import glob

OPTION_B_DIR = "/tmp/yaml-benchmark/option-b/rules"
OPTION_F_DIR = "/tmp/yaml-benchmark/option-f/rules"
OPTION_H_DIR = "/tmp/yaml-benchmark/option-h/rules"

# 3x scale dirs
SCALE_DIRS = {
    'b': "/tmp/yaml-benchmark/scale3x/option-b/rules",
    'd': "/tmp/yaml-benchmark/scale3x/option-d/rules",
    'e': "/tmp/yaml-benchmark/scale3x/option-e/rules",
    'f': "/tmp/yaml-benchmark/scale3x/option-f/rules",
    'h': "/tmp/yaml-benchmark/scale3x/option-h/rules",
}

for d in [OPTION_F_DIR, OPTION_H_DIR] + list(SCALE_DIRS.values()):
    os.makedirs(d, exist_ok=True)

def escape_bash(s):
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('$', '\\$')
    s = s.replace('`', '\\`')
    return s

def escape_dollar_single(s):
    return s.replace("'", "\\'").replace('\n', '\\n')

def parse_rule_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    suffixes = re.findall(r'^RULE_([A-Z0-9_]+)_ID=', content, re.MULTILINE)
    rules = []
    for suffix in suffixes:
        rule = {'suffix': suffix}
        for field in ['ID', 'ACTION', 'COMMAND', 'PATTERN', 'LEVEL', 'EMOJI', 'DESC', 'DOCS', 'BYPASS']:
            m = re.search(rf'^RULE_{suffix}_{field}="(.*?)"', content, re.MULTILINE)
            rule[field.lower()] = m.group(1) if m else ''
        m = re.search(rf'^RULE_{suffix}_AI_WARNING="(.*?)"$', content, re.MULTILINE | re.DOTALL)
        rule['ai_warning'] = m.group(1) if m else ''
        m = re.search(rf'^RULE_{suffix}_ALTERNATIVES=\((.*?)\)', content, re.MULTILINE | re.DOTALL)
        rule['alternatives'] = re.findall(r'"(.*?)"', m.group(1), re.DOTALL) if m else []
        m = re.search(rf'^RULE_{suffix}_VERIFY=\((.*?)\)', content, re.MULTILINE | re.DOTALL)
        rule['verify'] = re.findall(r'"(.*?)"', m.group(1), re.DOTALL) if m else []
        rules.append(rule)
    return rules

def write_option_f(rules, basename, outdir):
    """Option F: Direct registration, no intermediary variables."""
    path = os.path.join(outdir, basename)
    with open(path, 'w') as f:
        f.write('#!/usr/bin/env bash\n# Option F: Direct registration\n# shellcheck disable=SC2034\n\n')
        for r in rules:
            s = r['suffix']
            ai = escape_dollar_single(r['ai_warning']) if r['ai_warning'] else ''
            ai_arg = f"$'{ai}'" if ai else '""'
            f.write(f'_reg "{s}" "{escape_bash(r["id"])}" "{r["action"]}" "{escape_bash(r["command"])}" '
                    f'"{escape_bash(r["pattern"])}" "{r["level"]}" '
                    f'"{escape_bash(r["emoji"])}" "{escape_bash(r["desc"])}" '
                    f'"{escape_bash(r["docs"])}" "{escape_bash(r["bypass"])}" '
                    f'{ai_arg}\n')
            if r['alternatives']:
                parts = ' '.join(f'"{escape_bash(a)}"' for a in r['alternatives'])
                f.write(f'_alts "{r["id"]}" {parts}\n')
            if r['verify']:
                parts = ' '.join(f'"{escape_bash(v)}"' for v in r['verify'])
                f.write(f'_verify "{r["id"]}" {parts}\n')
            f.write('\n')
    return path

def write_option_h(rules, basename, outdir):
    """Option H: Heredoc data tables."""
    path = os.path.join(outdir, basename.replace('.sh', '.rules'))
    with open(path, 'w') as f:
        f.write(f'# Option H: Data table format - {basename}\n\n')
        for r in rules:
            f.write(f'RULE {r["id"]} {r["command"]} {r["action"]} {r["level"]} {r["emoji"]}\n')
            if r['pattern']:
                f.write(f'PAT {r["pattern"]}\n')
            else:
                f.write('PAT \n')
            f.write(f'DESC {r["desc"]}\n')
            if r['bypass']:
                f.write(f'BYP {r["bypass"]}\n')
            if r['docs']:
                f.write(f'DOCS {r["docs"]}\n')
            for alt in r['alternatives']:
                f.write(f'ALT {alt}\n')
            for ver in r['verify']:
                f.write(f'CHK {ver}\n')
            if r['ai_warning']:
                for line in r['ai_warning'].split('\n'):
                    if line.strip():
                        f.write(f'AI {line}\n')
            f.write('END\n\n')
    return path

def write_option_b_3x(rules, basename, outdir, copy_num):
    """Scale original bash rules 3x."""
    path = os.path.join(outdir, f'{basename[:-3]}_copy{copy_num}.sh')
    with open(path, 'w') as f:
        f.write(f'#!/usr/bin/env bash\n# 3x scale copy {copy_num}\n# shellcheck disable=SC2034\n\n')
        for r in rules:
            s = f'{r["suffix"]}_C{copy_num}'
            rid = f'{r["id"]}_c{copy_num}'
            ai = escape_bash(r['ai_warning'])
            f.write(f'RULE_{s}_ID="{rid}"\n')
            f.write(f'RULE_{s}_ACTION="{r["action"]}"\n')
            f.write(f'RULE_{s}_COMMAND="{escape_bash(r["command"])}"\n')
            f.write(f'RULE_{s}_PATTERN="{escape_bash(r["pattern"])}"\n')
            f.write(f'RULE_{s}_LEVEL="{r["level"]}"\n')
            f.write(f'RULE_{s}_EMOJI="{escape_bash(r["emoji"])}"\n')
            f.write(f'RULE_{s}_DESC="{escape_bash(r["desc"])}"\n')
            f.write(f'RULE_{s}_DOCS="{escape_bash(r["docs"])}"\n')
            f.write(f'RULE_{s}_BYPASS="{escape_bash(r["bypass"])}"\n')
            alts_str = '\n'.join(f'    "{escape_bash(a)}"' for a in r['alternatives'])
            f.write(f'RULE_{s}_ALTERNATIVES=(\n{alts_str}\n)\n' if alts_str else f'RULE_{s}_ALTERNATIVES=()\n')
            vers_str = '\n'.join(f'    "{escape_bash(v)}"' for v in r['verify'])
            f.write(f'RULE_{s}_VERIFY=(\n{vers_str}\n)\n' if vers_str else f'RULE_{s}_VERIFY=()\n')
            f.write(f'RULE_{s}_AI_WARNING="{ai}"\n\n')
        # Register function
        f.write('_command_safety_register_rules() {\n')
        for r in rules:
            s = f'{r["suffix"]}_C{copy_num}'
            f.write(f'    command_safety_register_rule "{s}" \\\n')
            f.write(f'        "$RULE_{s}_ID" "$RULE_{s}_ACTION" "$RULE_{s}_COMMAND" "$RULE_{s}_PATTERN" "$RULE_{s}_LEVEL" \\\n')
            f.write(f'        "$RULE_{s}_EMOJI" "$RULE_{s}_DESC" "$RULE_{s}_DOCS" "$RULE_{s}_BYPASS" "$RULE_{s}_AI_WARNING" "" \\\n')
            f.write(f'        "RULE_{s}_ALTERNATIVES" "RULE_{s}_VERIFY"\n')
        f.write('}\n')
    return path

def write_option_d_3x(rules, basename, outdir, copy_num):
    path = os.path.join(outdir, f'{basename[:-3]}_copy{copy_num}.sh')
    with open(path, 'w') as f:
        f.write(f'#!/usr/bin/env bash\n# 3x scale copy {copy_num}\n# shellcheck disable=SC2034\n\n')
        for r in rules:
            rid = f'{r["id"]}_c{copy_num}'
            ai = escape_dollar_single(r['ai_warning']) if r['ai_warning'] else ''
            f.write(f'_rule "{rid}" "{escape_bash(r["command"])}" '
                    f'"{escape_bash(r["pattern"])}" "{r["action"]}" "{r["level"]}" "{escape_bash(r["emoji"])}" \\\n'
                    f'    "{escape_bash(r["desc"])}" "{escape_bash(r["docs"])}" "{escape_bash(r["bypass"])}"\n')
            if r['alternatives']:
                parts = ' '.join(f'"{escape_bash(a)}"' for a in r['alternatives'])
                f.write(f'_alts "{rid}" {parts}\n')
            if r['verify']:
                parts = ' '.join(f'"{escape_bash(v)}"' for v in r['verify'])
                f.write(f'_verify "{rid}" {parts}\n')
            if ai:
                f.write(f"_ai \"{rid}\" $'{ai}'\n")
            f.write('\n')
    return path

def write_option_e_3x(rules, basename, outdir, copy_num):
    path = os.path.join(outdir, f'{basename[:-3]}_copy{copy_num}.sh')
    with open(path, 'w') as f:
        f.write(f'#!/usr/bin/env bash\n# 3x scale copy {copy_num}\n# shellcheck disable=SC2034\n\n')
        for r in rules:
            rid = f'{r["id"]}_c{copy_num}'
            ai = escape_dollar_single(r['ai_warning']) if r['ai_warning'] else ''
            f.write(f'_R id="{rid}" cmd="{escape_bash(r["command"])}" '
                    f'pat="{escape_bash(r["pattern"])}" act="{r["action"]}" lvl="{r["level"]}" \\\n'
                    f'   em="{escape_bash(r["emoji"])}" desc="{escape_bash(r["desc"])}" '
                    f'docs="{escape_bash(r["docs"])}" byp="{escape_bash(r["bypass"])}"\n')
            if r['alternatives']:
                parts = ' '.join(f'"{escape_bash(a)}"' for a in r['alternatives'])
                f.write(f'_A "{rid}" {parts}\n')
            if r['verify']:
                parts = ' '.join(f'"{escape_bash(v)}"' for v in r['verify'])
                f.write(f'_V "{rid}" {parts}\n')
            if ai:
                f.write(f"_W \"{rid}\" $'{ai}'\n")
            f.write('\n')
    return path

def write_option_f_3x(rules, basename, outdir, copy_num):
    path = os.path.join(outdir, f'{basename[:-3]}_copy{copy_num}.sh')
    with open(path, 'w') as f:
        f.write(f'#!/usr/bin/env bash\n# 3x scale copy {copy_num}\n# shellcheck disable=SC2034\n\n')
        for r in rules:
            s = f'{r["suffix"]}_C{copy_num}'
            rid = f'{r["id"]}_c{copy_num}'
            ai = escape_dollar_single(r['ai_warning']) if r['ai_warning'] else ''
            ai_arg = f"$'{ai}'" if ai else '""'
            f.write(f'_reg "{s}" "{rid}" "{r["action"]}" "{escape_bash(r["command"])}" '
                    f'"{escape_bash(r["pattern"])}" "{r["level"]}" '
                    f'"{escape_bash(r["emoji"])}" "{escape_bash(r["desc"])}" '
                    f'"{escape_bash(r["docs"])}" "{escape_bash(r["bypass"])}" '
                    f'{ai_arg}\n')
            if r['alternatives']:
                parts = ' '.join(f'"{escape_bash(a)}"' for a in r['alternatives'])
                f.write(f'_alts "{rid}" {parts}\n')
            if r['verify']:
                parts = ' '.join(f'"{escape_bash(v)}"' for v in r['verify'])
                f.write(f'_verify "{rid}" {parts}\n')
            f.write('\n')
    return path

def write_option_h_3x(rules, basename, outdir, copy_num):
    path = os.path.join(outdir, f'{basename[:-3]}_copy{copy_num}.rules')
    with open(path, 'w') as f:
        f.write(f'# 3x scale copy {copy_num}\n\n')
        for r in rules:
            rid = f'{r["id"]}_c{copy_num}'
            f.write(f'RULE {rid} {r["command"]} {r["action"]} {r["level"]} {r["emoji"]}\n')
            f.write(f'PAT {r["pattern"]}\n' if r['pattern'] else 'PAT \n')
            f.write(f'DESC {r["desc"]}\n')
            if r['bypass']: f.write(f'BYP {r["bypass"]}\n')
            if r['docs']: f.write(f'DOCS {r["docs"]}\n')
            for alt in r['alternatives']: f.write(f'ALT {alt}\n')
            for ver in r['verify']: f.write(f'CHK {ver}\n')
            if r['ai_warning']:
                for line in r['ai_warning'].split('\n'):
                    if line.strip(): f.write(f'AI {line}\n')
            f.write('END\n\n')
    return path

# ============= MAIN =============
all_rules_by_file = {}
total_rules = 0

for filepath in sorted(glob.glob(os.path.join(OPTION_B_DIR, "*.sh"))):
    basename = os.path.basename(filepath)
    if basename == 'settings.sh':
        continue
    rules = parse_rule_file(filepath)
    all_rules_by_file[basename] = rules
    total_rules += len(rules)

print(f"Parsed {total_rules} rules from {len(all_rules_by_file)} files\n")

# Generate 1x versions (F and H)
f_total = h_total = 0
for basename, rules in all_rules_by_file.items():
    fp = write_option_f(rules, basename, OPTION_F_DIR)
    hp = write_option_h(rules, basename, OPTION_H_DIR)
    with open(fp) as x: fl = len(x.readlines())
    with open(hp) as x: hl = len(x.readlines())
    f_total += fl
    h_total += hl
    print(f"  {basename}: F={fl} H={hl}")

print(f"\n1x totals: F={f_total} H={h_total}")

# Generate 3x scaled versions for B, D, E, F, H
print("\n=== Generating 3x scale (213 rules) ===")
for basename, rules in all_rules_by_file.items():
    for copy in [2, 3]:  # copy 1 = originals
        write_option_b_3x(rules, basename, SCALE_DIRS['b'], copy)
        write_option_d_3x(rules, basename, SCALE_DIRS['d'], copy)
        write_option_e_3x(rules, basename, SCALE_DIRS['e'], copy)
        write_option_f_3x(rules, basename, SCALE_DIRS['f'], copy)
        write_option_h_3x(rules, basename, SCALE_DIRS['h'], copy)

# Copy originals as copy1 for B
for filepath in sorted(glob.glob(os.path.join(OPTION_B_DIR, "*.sh"))):
    basename = os.path.basename(filepath)
    if basename == 'settings.sh': continue
    import shutil
    shutil.copy2(filepath, os.path.join(SCALE_DIRS['b'], f'{basename[:-3]}_copy1.sh'))

# Copy D originals as copy1
for filepath in sorted(glob.glob("/tmp/yaml-benchmark/option-d/rules/*.sh")):
    basename = os.path.basename(filepath)
    if basename == 'settings.sh': continue
    import shutil
    shutil.copy2(filepath, os.path.join(SCALE_DIRS['d'], f'{basename[:-3]}_copy1.sh'))

# Copy E originals as copy1
for filepath in sorted(glob.glob("/tmp/yaml-benchmark/option-e/rules/*.sh")):
    basename = os.path.basename(filepath)
    if basename == 'settings.sh': continue
    import shutil
    shutil.copy2(filepath, os.path.join(SCALE_DIRS['e'], f'{basename[:-3]}_copy1.sh'))

# Copy F originals as copy1
for filepath in sorted(glob.glob(os.path.join(OPTION_F_DIR, "*.sh"))):
    basename = os.path.basename(filepath)
    import shutil
    shutil.copy2(filepath, os.path.join(SCALE_DIRS['f'], f'{basename[:-3]}_copy1.sh'))

# Copy H originals as copy1
for filepath in sorted(glob.glob(os.path.join(OPTION_H_DIR, "*.rules"))):
    basename = os.path.basename(filepath)
    name = basename.replace('.rules', '')
    import shutil
    shutil.copy2(filepath, os.path.join(SCALE_DIRS['h'], f'{name}_copy1.rules'))

# Count 3x lines
for opt, d in SCALE_DIRS.items():
    ext = '.rules' if opt == 'h' else '.sh'
    total = sum(len(open(f).readlines()) for f in glob.glob(os.path.join(d, f'*{ext}')))
    files = len(glob.glob(os.path.join(d, f'*{ext}')))
    print(f"  3x Option {opt.upper()}: {total} lines ({files} files)")

print("\nDone!")
