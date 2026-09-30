#!/usr/bin/env python3
"""Rebuild the catalog from paired editorial copy and native service translations."""
import pathlib, re, json
root = pathlib.Path(__file__).resolve().parent.parent
strings = {}
def add(key, zh, en):
    strings[key] = {'extractionState':'manual','localizations':{lang:{'stringUnit':{'state':'translated','value':value}} for lang,value in [('en',en),('zh-Hans',zh)]}}
pattern = re.compile(r'L\("((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)')
for path in (root/'MetroFocus').rglob('*.swift'):
    for zh,en in pattern.findall(path.read_text()):
        zh = json.loads('"'+zh+'"'); en = json.loads('"'+en+'"')
        add(en,zh,en)
for zh,en in json.loads((root/'scripts/service_translations.json').read_text()).items(): add(zh,zh,en)
# Context keys keep wallet copy distinct from uppercase stamps and the Tickets tab.
add('wallet.footer', '你的每一分钟，都算数。', 'Every minute matters.')
add('wallet.ticketCount', '张车票', 'tickets')
# Uppercase signage must not collide with sentence-case generated symbols.
add('journey.arrivedLabel', '已到站', 'ARRIVED')
add('atlas.hereNowLabel', '此刻', 'HERE & NOW')
for zh,en in {
 '请填写 1–24 字的任务名称，并检查班次设置。':'Enter a task name of 1–24 characters and check the service settings.',
 '无法读取旅程记录。请重试；已有数据不会被清除。':'Could not read your journeys. Please retry; existing data will not be erased.',
 '旅程尚未保存。请重试保存，当前进度会保留。':'Your journey has not been saved. Please retry; your current progress is retained.'
}.items(): add(zh,zh,en)
(root/'MetroFocus/Resources/Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':dict(sorted(strings.items())),'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {len(strings)} localized strings')
