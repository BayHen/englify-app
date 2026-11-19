import ExcelJS from 'exceljs';

export const importHeaders=['external_id','question_type','cefr_level','topic','difficulty','prompt','passage','options_json','left_items_json','right_items_json','correct_answer_json','explanation_vi'] as const;
type ImportRecord=Record<(typeof importHeaders)[number],string>;

export function parseCsv(text:string):ImportRecord[]{
 if(new TextEncoder().encode(text).byteLength>2_000_000)throw new Error('Tệp vượt giới hạn 2 MB.');
 const rows:string[][]=[];let row:string[]=[],cell='',quoted=false;
 for(let i=0;i<text.length;i++){const char=text[i];if(quoted){if(char==='"'&&text[i+1]==='"'){cell+='"';i++;}else if(char==='"')quoted=false;else cell+=char;}else if(char==='"')quoted=true;else if(char===','){row.push(cell);cell='';}else if(char==='\n'){row.push(cell.replace(/\r$/,''));rows.push(row);row=[];cell='';}else cell+=char;}
 if(quoted)throw new Error('CSV có dấu ngoặc kép chưa đóng.');if(cell||row.length){row.push(cell.replace(/\r$/,''));rows.push(row);}if(rows.length<2)return[];
 const headers=rows[0].map(value=>value.replace(/^\uFEFF/,'').trim());for(const required of importHeaders)if(!headers.includes(required))throw new Error(`Thiếu cột ${required}.`);
 if(rows.length-1>500)throw new Error('Mỗi lần chỉ nhập tối đa 500 dòng.');return rows.slice(1).filter(values=>values.some(Boolean)).map(values=>Object.fromEntries(importHeaders.map(name=>[name,values[headers.indexOf(name)]?.trim()??''])) as ImportRecord);
}
function json(value:string,fallback:unknown){if(!value)return fallback;return JSON.parse(value) as unknown;}
export function normalizeImportRows(records:ImportRecord[]){return records.map(row=>({external_id:row.external_id||null,kind:row.question_type,cefr_level:row.cefr_level,topic:row.topic,difficulty:Number(row.difficulty),prompt:row.prompt,passage:row.passage||null,options:json(row.options_json,[]),left_items:json(row.left_items_json,[]),right_items:json(row.right_items_json,[]),answer:json(row.correct_answer_json,null),explanation_vi:row.explanation_vi,origin:'import'}));}
export async function parseXlsx(buffer:ArrayBuffer):Promise<ImportRecord[]>{
 if(buffer.byteLength>5_000_000)throw new Error('Tệp vượt giới hạn 5 MB.');const workbook=new ExcelJS.Workbook();await workbook.xlsx.load(buffer);const sheet=workbook.worksheets[0];if(!sheet)throw new Error('Workbook không có worksheet.');
 const headers=(sheet.getRow(1).values as unknown[]).slice(1).map(value=>String(value??'').trim());for(const required of importHeaders)if(!headers.includes(required))throw new Error(`Thiếu cột ${required}.`);if(sheet.actualRowCount-1>500)throw new Error('Mỗi lần chỉ nhập tối đa 500 dòng.');const result:ImportRecord[]=[];
 sheet.eachRow((excelRow,index)=>{if(index===1)return;const record={} as ImportRecord;for(const name of importHeaders){const cell=excelRow.getCell(headers.indexOf(name)+1);if(cell.formula)throw new Error(`Dòng ${index}: không chấp nhận công thức.`);const value=cell.value;record[name]=typeof value==='object'&&value!==null?'':String(value??'').trim();}if(Object.values(record).some(Boolean))result.push(record);});return result;
}
export function templateCsv(){return `${importHeaders.join(',')}\nexample-1,multiple_choice,A1,grammar,1,Choose the correct answer.,,"[{""id"":""a"",""text"":""Answer A""},{""id"":""b"",""text"":""Answer B""}]",[],[],"""a""",Giải thích tiếng Việt\n`;}
