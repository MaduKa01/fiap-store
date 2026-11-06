import json
from pathlib import Path
summary=[]
for name in ['store-api-1.0','store-api-2.0','store-worker-1.0','store-front-1.1']:
 p=Path('avaliacao/trivy')/(name+'.json')
 d=json.loads(p.read_text());counts={k:0 for k in ['CRITICAL','HIGH','MEDIUM','LOW','UNKNOWN']};lines=[]
 for result in d.get('Results',[]):
  for v in result.get('Vulnerabilities') or []:
   sev=v.get('Severity','UNKNOWN');counts[sev]=counts.get(sev,0)+1
   if sev=='CRITICAL':lines.append(' | '.join([v['VulnerabilityID'],v['PkgName'],v['InstalledVersion'],'correcao: '+v.get('FixedVersion','sem versao informada'),v.get('PrimaryURL','')]))
 (p.parent/(name+'-critical.txt')).write_text('\n'.join(lines)+'\n' if lines else 'Nenhuma CRITICAL encontrada neste scan.\n')
 summary.append({'image':name,'counts':counts,'createdAt':d.get('CreatedAt')})
Path('avaliacao/trivy/resumo.json').write_text(json.dumps(summary,indent=2)+'\n')
for row in summary:print(row['image'],row['counts'])
if any(r['counts']['CRITICAL'] for r in summary):raise SystemExit('Ha CRITICAL: revisar e justificar cada uma antes da entrega.')
