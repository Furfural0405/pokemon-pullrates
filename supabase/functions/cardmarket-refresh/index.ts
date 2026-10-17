const PROJECT=Deno.env.get('SUPABASE_URL')!;
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const headers={'apikey':SERVICE,'Authorization':`Bearer ${SERVICE}`,'Content-Type':'application/json'};
async function rpc(operation:string,payload:unknown){const r=await fetch(PROJECT+'/rest/v1/rpc/pull_market_worker',{method:'POST',headers,body:JSON.stringify({operation,payload}),signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('Worker authorization or storage failed');return r.json()}
async function source(path:string){const r=await fetch('https://downloads.s3.cardmarket.com/productCatalog/'+path,{signal:AbortSignal.timeout(30000)});if(!r.ok)throw Error('Cardmarket download failed: '+r.status);if(Number(r.headers.get('content-length'))>60000000)throw Error('Source too large');return r.json()}
Deno.serve(async req=>{
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const token=req.headers.get('x-price-worker-token')??'';
 if(token.length<32||token.length>256)return new Response('Unauthorized',{status:401});
 let claimed;try{claimed=await rpc('claim',{token})}catch{return new Response('Unauthorized',{status:401})}
 if(!claimed.run)return Response.json({skipped:true});
 try{
  const catalog=await source('productList/products_singles_6.json');
  if(!Array.isArray(catalog.products))throw Error('Invalid product catalogue');
  const products=catalog.products.filter((p:any)=>p.idExpansion===6603&&p.idCategory===51);
  if(!products.length||products.length>1000)throw Error('Unexpected set size');
  const ids=new Set(products.map((p:any)=>p.idProduct));
  if(ids.size!==products.length)throw Error('Duplicate products');
  const guide=await source('priceGuide/price_guide_6.json');
  if(!Array.isArray(guide.priceGuides)||!Number.isFinite(Date.parse(guide.createdAt)))throw Error('Invalid price guide');
  const prices=new Map(guide.priceGuides.filter((p:any)=>ids.has(p.idProduct)).map((p:any)=>[p.idProduct,p]));
  const valid=(n:unknown)=>typeof n==='number'&&Number.isFinite(n)&&n>=0?n:null;
  await rpc('finish',{token,source_at:guide.createdAt,products:products.map((p:any)=>{const v:any=prices.get(p.idProduct);return {product_id:p.idProduct,name:p.name,low:valid(v?.low),avg7:valid(v?.avg7)}})});
  return Response.json({ok:true,products:products.length,source_at:guide.createdAt});
 }catch(e){await rpc('fail',{token,error:e instanceof Error?e.message:'Refresh failed'}).catch(()=>{});return Response.json({error:'Price refresh failed; previous values retained'},{status:502})}
});
