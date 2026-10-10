import test from 'node:test';
import assert from 'node:assert/strict';
import {canUploadCardImage,IMAGE_OWNER} from '../card-images.js';
import {showRate} from '../stats.js';
test('only the exact owner account receives upload controls',()=>{
 assert.equal(canUploadCardImage(null),false);
 assert.equal(canUploadCardImage({id:'other',role:'admin'}),false);
 assert.equal(canUploadCardImage({id:IMAGE_OWNER}),true);
});
test('pull rates include reciprocal percentages and keep missing values distinct',()=>{
 assert.equal(showRate(5),'1 / 5 (20 %)');
 assert.equal(showRate(200),'1 / 200 (0,5 %)');
 assert.equal(showRate(4.69),'1 / 4,69 (21,32 %)');
 assert.equal(showRate(null),'Noch keine Pullrate');
 assert.equal(showRate(0),'Noch keine Pullrate');
});
