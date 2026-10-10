import test from 'node:test';
import assert from 'node:assert/strict';
import {RARITIES,validateCardDetails} from '../card-details.js';
test('card labels are trimmed and validated independently of card IDs',()=>{assert.deepEqual(validateCardDetails('  Mew ex  ','Special Art Rare'),{name:'Mew ex',rarity:'Special Art Rare'});for(const rarity of RARITIES)assert.equal(validateCardDetails('Mew',rarity).rarity,rarity);assert.throws(()=>validateCardDetails(' ','Rare'));assert.throws(()=>validateCardDetails('a'.repeat(101),'Rare'));assert.throws(()=>validateCardDetails('Mew','invalid'))});
