const ExcelJS = require('exceljs');

const XLSX_MIME =
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/**
 * Stream an xlsx file to the response.
 * columns: [{ header, key, width? }], rows: array of plain objects keyed by `key`.
 */
async function sendWorkbook(res, filename, sheetName, columns, rows) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'Attendance System';
  workbook.created = new Date();
  const sheet = workbook.addWorksheet(sheetName);
  sheet.columns = columns.map((c) => ({ header: c.header, key: c.key, width: c.width || 18 }));
  sheet.getRow(1).font = { bold: true };
  for (const row of rows) sheet.addRow(row);
  res.setHeader('Content-Type', XLSX_MIME);
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  await workbook.xlsx.write(res);
  res.end();
}

/** Load a workbook from an in-memory buffer (import uploads). */
async function loadWorkbook(buffer) {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(buffer);
  return workbook;
}

/** Robust cell reader: returns a trimmed string, or a Date for date cells. */
function cellValue(row, colIndex) {
  if (!colIndex) return '';
  const cell = row.getCell(colIndex);
  const v = cell.value;
  if (v === null || v === undefined) return '';
  if (v instanceof Date) return v;
  if (typeof v === 'object') {
    // richText / hyperlink / formula results
    if (v.result instanceof Date) return v.result;
    return String(cell.text || '').trim();
  }
  return String(v).trim();
}

module.exports = { sendWorkbook, loadWorkbook, cellValue, XLSX_MIME };
