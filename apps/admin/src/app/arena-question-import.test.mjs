import assert from 'node:assert/strict';
import test from 'node:test';
import ExcelJS from 'exceljs';
import { importHeaders, normalizeImportRows, parseCsv, parseXlsx } from './arena-question-import.ts';

test('parses quoted UTF-8 CSV and normalizes typed question fields',()=>{const csv=`${importHeaders.join(',')}\nexternal,multiple_choice,A1,grammar,1,"Choose, carefully",,"[{""id"":""a"",""text"":""café""},{""id"":""b"",""text"":""tea""}]",[],[],"""a""",Giải thích tiếng Việt\n`;const rows=normalizeImportRows(parseCsv(csv));assert.equal(rows[0].prompt,'Choose, carefully');assert.equal(rows[0].difficulty,1);assert.equal(rows[0].options[0].text,'café');});
test('rejects missing headers and oversized row counts',()=>{assert.throws(()=>parseCsv('prompt\nQuestion'),/Thiếu cột/);const csv=`${importHeaders.join(',')}\n${Array.from({length:501},()=>',,,,,,,,,,,').join('\n')}`;assert.throws(()=>parseCsv(csv),/500 dòng/);});
test('reads plain XLSX values and refuses formulas',async()=>{const workbook=new ExcelJS.Workbook(),sheet=workbook.addWorksheet('Questions');sheet.addRow([...importHeaders]);sheet.addRow(['x','fill_blank','A1','grammar',1,'Prompt','','[]','[]','[]','["answer"]','Giải thích']);const buffer=await workbook.xlsx.writeBuffer();assert.equal((await parseXlsx(buffer)).length,1);sheet.getCell(2,6).value={formula:'1+1',result:2};const unsafe=await workbook.xlsx.writeBuffer();await assert.rejects(()=>parseXlsx(unsafe),/không chấp nhận công thức/);});
