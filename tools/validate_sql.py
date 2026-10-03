"""Syntax-only SQL/PLpgSQL checks; this never connects to a database.

Install pglast==8.4 in .dart_tool/sql-audit, then run this with file arguments.
For psql test scripts, replace the two UUID variables only for parsing.
Passing syntax does NOT validate grants, table resolution, RLS or runtime effects.
"""
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.dart_tool' / 'sql-audit'))
from pglast import parse_sql
from pglast.parser import parse_plpgsql_json

for name in sys.argv[1:]:
    source = Path(name).read_text(encoding='utf-8-sig')
    source = re.sub(r'^\\.*$', '', source, flags=re.M)
    source = source.replace(":'user_a'", "'00000000-0000-4000-8000-000000000001'")
    source = source.replace(":'user_b'", "'00000000-0000-4000-8000-000000000002'")
    statements = parse_sql(source)
    functions = re.findall(r'create\s+(?:or\s+replace\s+)?function\b.*?\$\$;', source, re.I | re.S)
    for function in functions:
        if re.search(r'language\s+plpgsql', function, re.I):
            parse_plpgsql_json(function)
    blocks = re.findall(r'\bdo\s+\$\$.*?\$\$;', source, re.I | re.S)
    for block in blocks:
        parse_plpgsql_json(block)
    print(f'{name}: SQL OK ({len(statements)} statements, {len(functions)} functions, {len(blocks)} DO bodies)')
