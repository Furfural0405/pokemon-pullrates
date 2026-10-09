import {build} from 'esbuild';
import {rm,mkdir,copyFile,cp,writeFile} from 'node:fs/promises';
await rm('dist',{recursive:true,force:true});await mkdir('dist',{recursive:true});
for(const f of ['index.html','style.css','favicon.svg','cards.json'])await copyFile(f,'dist/'+f);
await cp('assets','dist/assets',{recursive:true});
await build({entryPoints:['app.js'],bundle:true,format:'esm',minify:true,outfile:'dist/app.js',target:['es2022']});
await writeFile('dist/.nojekyll','');
console.log('Static build ready in dist/');
