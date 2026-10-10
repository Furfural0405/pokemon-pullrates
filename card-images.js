export const IMAGE_OWNER='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
export function canUploadCardImage(user){return user?.id===IMAGE_OWNER}
export async function prepareCardImage(file){
 if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw Error('Bitte ein JPG-, PNG- oder WebP-Bild auswählen.');
 if(file.size>20*1024*1024)throw Error('Das Bild darf höchstens 20 MB groß sein.');
 const bitmap=await createImageBitmap(file);
 try{
  const scale=Math.min(1,1600/Math.max(bitmap.width,bitmap.height));
  const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
  canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
  const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',0.92));
  if(!blob||blob.type!=='image/webp'||blob.size>5*1024*1024)throw Error('Das Bild konnte nicht als WebP unter 5 MB vorbereitet werden.');
  return blob;
 }finally{bitmap.close()}
}
