#!/usr/bin/env python3
"""Ensaio real dos dez desafios. Nao exclui PVC, volume, namespace ou cluster."""
import json,os,subprocess,time,datetime,sys,threading
from pathlib import Path
from zoneinfo import ZoneInfo
ROOT=Path(__file__).resolve().parent.parent
os.chdir(ROOT)
os.environ.update(AWS_PROFILE='default',AWS_REGION='us-east-1',AWS_DEFAULT_REGION='us-east-1',KUBECONFIG=str(ROOT/'.kubeconfig'),GIT_TERMINAL_PROMPT='0')
K=str(ROOT/'.runtime/bin/kubectl')
STAMP=datetime.datetime.now(ZoneInfo('America/Sao_Paulo')).strftime('%Y-%m-%d_%H-%M-%S')
OUT=ROOT/'evidencias'/('ensaio-'+STAMP);OUT.mkdir(parents=True,exist_ok=True)
LOG=None

def say(s):
 print(s,flush=True)
 if LOG:LOG.write(s+'\n');LOG.flush()

def run(args,ok=True,timeout=120):
 say('$ '+' '.join(args))
 r=subprocess.run(args,text=True,capture_output=True,timeout=timeout)
 if r.stdout.strip():say(r.stdout.strip())
 if r.stderr.strip():say(r.stderr.strip())
 if ok and r.returncode:raise RuntimeError('Falhou: '+args[0]+' (codigo '+str(r.returncode)+')')
 return r

def k(*args,**kw):return run([K,*args],**kw)
def get(kind,name=None,ns=None):
 args=['get',kind]+([name] if name else [])+(['-n',ns] if ns else [])+['-o','json']
 # Leitura silenciosa para as observacoes repetidas.
 r=subprocess.run([K,*args],capture_output=True,text=True,timeout=40,check=True)
 return json.loads(r.stdout)
def wait(fn,timeout=240):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  try:
   if fn():return
  except (subprocess.SubprocessError,ValueError,KeyError):pass
  time.sleep(3)
 raise TimeoutError('Condicao nao atingida em '+str(timeout)+'s')
def api(path,post=False):
 r=subprocess.run(['curl','-kfsS','--connect-timeout','5','--max-time','20',*(['-X','POST'] if post else []),URL+path],capture_output=True,text=True,timeout=25,check=True)
 return json.loads(r.stdout)
def ready_api():
 d=get('deploy','store-api','store-prod');return d['status'].get('readyReplicas',0)>=max(3,d['spec'].get('replicas',0))
def apphealthy():
 d=get('application','fiap-store','argocd');return d.get('status',{}).get('sync',{}).get('status')=='Synced' and d.get('status',{}).get('health',{}).get('status')=='Healthy'
def snapshot():
 k('get','nodes','-L','topology.kubernetes.io/zone')
 k('-n','store-prod','get','deploy,hpa,scaledobject,job,cronjob,pdb,ingress')
 k('-n','store-data','get','pods,pvc')
 k('-n','argocd','get','application','fiap-store')
def selfheal():
 before=get('pods',ns='store-prod')['items'];pods=[p for p in before if p['metadata'].get('labels',{}).get('app')=='store-api']
 old={p['metadata']['uid'] for p in pods};victim=pods[0]['metadata']['name']
 k('-n','store-prod','delete','pod',victim,'--wait=true')
 def recovered():
  current=[p for p in get('pods',ns='store-prod')['items'] if p['metadata'].get('labels',{}).get('app')=='store-api']
  return ready_api() and bool({p['metadata']['uid'] for p in current}-old)
 wait(recovered);k('-n','store-prod','get','pods','-l','app=store-api','-o','wide');assert api('/api/produtos')
 say('OK: uma nova replica foi criada e a API responde.')
def keda():
 wait(lambda:get('deploy','store-worker','store-prod')['spec'].get('replicas',0)==0)
 say('INICIAL: worker com zero replicas.');say(json.dumps(api('/api/pedidos')))
 batch=api('/api/pedidos/lote?quantidade=50',True);assert batch['criados']==50;say(json.dumps(batch))
 timeline=[];peak=0;active=False
 def finished():
  nonlocal peak,active
  d=get('deploy','store-worker','store-prod');desired=d['spec'].get('replicas',0);ready=d['status'].get('readyReplicas',0)
  peak=max(peak,desired);active=active or ready>0
  row={'hora':datetime.datetime.now(ZoneInfo('America/Sao_Paulo')).isoformat(),'replicas':desired,'ready':ready};timeline.append(row);say(json.dumps(row))
  return active and desired==0 and api('/api/pedidos')['resumo']['pendentes']==0
 wait(finished,420);(OUT/'keda-timeline.json').write_text(json.dumps(timeline,indent=2));say('OK: worker saiu de zero, processou 50 pedidos e voltou a zero. Pico observado: '+str(peak))
def report():
 name='report-ensaio-'+str(int(time.time()));k('-n','store-prod','create','job','--from=cronjob/store-report',name)
 k('-n','store-prod','wait','--for=condition=complete','job/'+name,'--timeout=180s',timeout=200)
 say(json.dumps(api('/api/relatorios'),ensure_ascii=False));say('OK: Job de relatorio concluido.')
def rbac():
 for args,expected in [(['list','pods'],'yes'),(['get','pods','--subresource=log'],'yes'),(['delete','pods'],'no'),(['get','secrets'],'no'),(['create','pods','--subresource=exec'],'no')]:
  r=k('auth','can-i',*args,'-n','store-prod','--as=dev.aluno','--as-group=fiap:devs',ok=False)
  assert r.stdout.strip()==expected,(args,r.stdout)
 say('OK: duas permissoes de leitura e tres negacoes confirmadas.')
def network():
 r=k('-n','store-prod','exec','deploy/store-front','--','nc','-z','-w','3','store-db.store-data.svc.cluster.local','5432',ok=False);assert r.returncode!=0
 k('-n','store-prod','exec','deploy/store-api','--','python','-c',"import socket; socket.create_connection(('store-db.store-data.svc.cluster.local',5432),3); print('API conecta no banco')")
 say('OK: front bloqueado e API permitida no banco.')
def psa():
 r=k('-n','store-prod','run','psa-ensaio','--image=busybox:1.36','--privileged','--restart=Never','--dry-run=server','--','sleep','10',ok=False)
 assert r.returncode!=0 and 'restricted' in (r.stderr+r.stdout)
 say('OK: a admissao recusou o Pod privilegiado; nenhum Pod foi criado.')
def persistence():
 before=api('/api/pedidos?limite=200');ids={p['id'] for p in before['pedidos']};assert ids,'Gere pedidos antes do teste'
 pvc=get('pvc','data-store-db-0','store-data');uid=pvc['metadata']['uid'];volume=pvc['spec']['volumeName'];say('ANTES: '+json.dumps({'pedidos':len(ids),'pvcUID':uid,'volume':volume}))
 k('-n','store-data','delete','pod','store-db-0','--wait=true');k('-n','store-data','wait','pod/store-db-0','--for=condition=Ready','--timeout=240s',timeout=260)
 wait(lambda:bool(api('/api/produtos')),180)
 after=api('/api/pedidos?limite=200');assert ids<={p['id'] for p in after['pedidos']}
 current=get('pvc','data-store-db-0','store-data');assert current['metadata']['uid']==uid and current['spec']['volumeName']==volume
 say('OK: '+str(len(ids))+' pedidos e o mesmo PVC/volume preservados apos recriar o Pod do banco.')
def drain():
 db=get('pod','store-db-0','store-data');dbnode=db['spec']['nodeName'];nodes=get('nodes')['items'];zone=next(n['metadata']['labels']['topology.kubernetes.io/zone'] for n in nodes if n['metadata']['name']==dbnode)
 candidates=[n['metadata']['name'] for n in nodes if n['metadata']['name']!=dbnode and not n['spec'].get('unschedulable') and n['metadata']['labels']['topology.kubernetes.io/zone']==zone]
 assert candidates,'Sem segundo no na zona do banco; escolher manualmente sem remover a unica capacidade da zona'
 node=candidates[0];say('No do banco preservado: '+dbnode+'; no para manutencao: '+node)
 try:
  k('drain',node,'--ignore-daemonsets','--delete-emptydir-data','--timeout=300s',timeout=330);wait(ready_api,180);assert api('/api/produtos');say('OK: drenagem respeitou os PDBs e a API responde.')
 finally:k('uncordon',node)
def drift():
 old=get('svc','store-front','store-prod')['metadata']['uid'];k('-n','store-prod','delete','service','store-front')
 wait(lambda:get('svc','store-front','store-prod')['metadata']['uid']!=old,240)
 say('OK: Argo CD recriou o Service com um novo UID.');k('-n','store-prod','get','service','store-front');wait(apphealthy,240)
def version(tag):
 p=ROOT/'k8s/07-app.yaml';t=p.read_text();import re
 new=re.sub(r'(897783914221\.dkr\.ecr\.us-east-1\.amazonaws\.com/store-api:)[0-9.]+',r'\g<1>'+tag,t);assert new!=t,'Tag ja selecionada'
 p.write_text(new);run(['git','add','k8s/07-app.yaml']);run(['git','commit','-m','Demonstra versao '+tag+' da API por GitOps']);run(['git','push','origin','main'],timeout=120)
 k('-n','argocd','annotate','application','fiap-store','argocd.argoproj.io/refresh=normal','--overwrite')
 wait(lambda:get('deploy','store-api','store-prod')['spec']['template']['spec']['containers'][0]['image'].endswith(':'+tag),300)
 k('-n','store-prod','rollout','status','deploy/store-api','--timeout=240s',timeout=260);wait(apphealthy,240)
 wait(lambda:api('/api/plataforma')['versao']==tag,120);say('OK: API '+tag+' confirmada por HTTPS.')
def rollback():
 try:version('1.0')
 finally:
  if 'store-api:1.0' in (ROOT/'k8s/07-app.yaml').read_text():version('2.0')
 say('OK: rollback para 1.0 e restauracao para 2.0 feitos por commit.')

if __name__=='__main__':
 account=run(['aws','sts','get-caller-identity','--query','Account','--output','text']).stdout.strip();assert account=='897783914221'
 host=get('svc','traefik','traefik')['status']['loadBalancer']['ingress'][0]['hostname'];assert host.endswith('.elb.amazonaws.com');URL='https://'+host
 wait(ready_api);assert api('/api/produtos');snapshot()
 cases=[('01-self-healing',selfheal),('02-keda',keda),('03-relatorio',report),('04-rbac',rbac),('05-rede',network),('06-pod-security',psa),('07-persistencia',persistence),('08-drenagem',drain),('09-drift',drift),('10-rollback',rollback)]
 results=[]
 for name,fn in cases:
  LOG=(OUT/(name+'.txt')).open('w');say('\nDESAFIO '+name+' | '+STAMP)
  try:fn();results.append({'desafio':name,'resultado':'OK'})
  except Exception as e:
   say('FALHA: '+str(e));results.append({'desafio':name,'resultado':'FALHA','detalhe':str(e)});break
  finally:LOG.close();LOG=None
  (OUT/'resumo.json').write_text(json.dumps(results,indent=2,ensure_ascii=False))
 (OUT/'resumo.json').write_text(json.dumps(results,indent=2,ensure_ascii=False));say(json.dumps(results,indent=2,ensure_ascii=False));snapshot()
 if len(results)!=10 or any(r['resultado']!='OK' for r in results):raise SystemExit(1)
