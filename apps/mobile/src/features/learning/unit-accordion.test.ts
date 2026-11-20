import { describe, expect, it } from 'vitest';
import { toggleExpandedUnit } from './unit-accordion';

describe('toggleExpandedUnit',()=>{
  it('opens the pressed unit when every unit is collapsed',()=>{
    expect(toggleExpandedUnit(null,'unit-1')).toBe('unit-1');
  });
  it('closes the currently expanded unit',()=>{
    expect(toggleExpandedUnit('unit-1','unit-1')).toBeNull();
  });
  it('opens a different unit and implicitly closes the previous one',()=>{
    expect(toggleExpandedUnit('unit-1','unit-2')).toBe('unit-2');
  });
});

