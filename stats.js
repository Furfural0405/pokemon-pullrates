export const FORMAT='pokemon-pullrates';
export function boosters(counts,cards){return cards.filter(c=>c.booster_slot).reduce((s,c)=>s+(counts[c.id]??0),0)}
export function rates(counts,cards){const b=boosters(counts,cards);return Object.fromEntries(cards.map(c=>[c.id,b>0&&counts[c.id]>0?Math.round(b/counts[c.id]*100)/100:null]))}
export function validateCounts(counts,cards){
 if(!counts||typeof counts!=='object'||Array.isArray(counts))throw Error('Ungültige Kartenwerte.');
 const ids=new Set(cards.map(c=>c.id));
 for(const [id,n] of Object.entries(counts))if(!ids.has(id)||!Number.isSafeInteger(n)||n<0||n>1000000)throw Error(`Ungültiger Wert für ${id}. Erlaubt: ganze Zahlen von 0 bis 1.000.000.`);
 return counts;
}
export function validateBackup(data,cards){
 if(!data||data.format!==FORMAT||data.schema_version!==1||data.set!=='30thC-zh-Hans')throw Error('Kein kompatibles Backup für dieses Set.');
 if(data.scope==='own')validateCounts(data.counts,cards);
 else if(data.scope==='all'){
  if(!Array.isArray(data.datasets)||data.datasets.length>10000)throw Error('Ungültige Datensätze.');
  const ids=new Set();for(const d of data.datasets){if(!/^[0-9a-f-]{36}$/i.test(d.user_id)||ids.has(d.user_id))throw Error('Ungültige oder doppelte Nutzer-ID.');ids.add(d.user_id);validateCounts(d.counts,cards);if(d.snapshot!==null)validateCounts(d.snapshot,cards)}
 }else throw Error('Unbekannter Backup-Typ.');return data;
}
export function showRate(value){if(value==null||!Number.isFinite(value)||value<=0)return 'Noch keine Pullrate';const f=new Intl.NumberFormat('de-DE',{maximumFractionDigits:2});return `1 / ${f.format(value)} (${f.format(100/value)} %)`}
