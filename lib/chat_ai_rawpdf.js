const fs = require('fs');
const mysql = require('mysql2/promise');
const PDFDocument = require('pdfkit');
const cron = require('node-cron');

const FIXED_TEXT_1 = 'DỮ LIỆU BÁO CÁO SÂN BAY NỘI BÀI HÔM NAY';
const FIXED_TEXT_2 = 'Bảng kế hoạch công việc cho giám sát dịch vụ (Vị trí bắt đầu bằng GS) và công nhân (Vị trí không bắt đầu bằng GS).Mỗi dòng là 1 công việc quy định ở cột Mô tả, giờ làm ở cột Bắt đầu & Kết thúc. Cột Ngày quy định ngày trong tuần áp dụng, nếu để trống/ không quy định nghĩa là tất cả các ngày từ thứ 2 đến hết chủ nhật, trong đó thứ 2=2, chủ nhật=1, thứ 7= 7. VD: 7,1,5 là làm vào Thứ 7, Chủ nhật, Thứ 5. Cột Vị trí là tên Vị trí thực hiện công việc. Thứ tự các cột trong bảng: Vị trí, Ngày, Bắt đầu, Kết thúc, Mô tả';
const FIXED_TEXT_3 = 'Lịch sử báo cáo 7 ngày gần nhất, được tạo bởi 3 nhóm chính. Nhóm 1: Robot tự động (cột Tài khoản= hm.gausium), chỉ có 1 loại báo cáo Phân loại là Robot, tại cột Kế hoạch sẽ là ID của robot đó, cột Chi tiết là nội dung báo cáo theo mẫu: * Số CN sử dụng: 1* Diện tích sử dụng (m2): 197.445* Diện tích kế hoạch: 585.613* Tỉ lệ hoàn thành: 0.337* Tốc độ m2/giờ: 683.229* Lít nước tiêu thụ: 3.178* Thời gian sử dụng (phút): 17* Lượng pin tiêu thụ: 9 trong đó tỉ lệ hoàn thành là số %, vd: 0.33 là 33%. Nhóm 2 là Giám sát, các Tài khoản bắt đầu với hm. (không tính hm.gausium), trong báo cáo có các Phân loại khác nhau, trong Phân loại = Kiểm tra chất lượng, ở cột Kế hoạch sẽ khi kế hoạch công việc là gì theo mẫu Giờ gắt đầu-Giờ kết thúc-Mô tả theo kế hoạch, cột Vị trí là Vị trí theo lịch họ đảm nhiệm hôm đó, nếu Phân loại là Máy móc ở cột Kế hoạch sẽ là ID của máy được dùng, trong Chi tiết sẽ theo mẫu: * Số CN sử dụng: 1* Diện tích sử dụng (m2): 80* Đã vệ sinh: Có* Thời gian sử dụng (phút): 15* Mô tả tình trạng: * LLV: Khác. Nhóm thứ 3 là công nhân, có Tài khoản không bắt đầu bằng hm. Nhóm 2 & 3 có nhiều Phân loại báo cáo khác nhau ngoài Máy móc & Kiểm tra chất lượng/ Chất lượng là chính. Thứ tự các cột trong bảng này: Tải khoản, Ngày (định dạng YYYY-MM-DD), Giờ (HH:MM:SS), Chi tiết, Kế hoạch, Vị trí, Phân loại, Hình ảnh (Có/Không)';

const dbConfig = require('./dangnhap.js');

function drawTable(doc, data, startY, customWidths = null) {
  if (data.length === 0) return startY;
  
  const cols = Object.keys(data[0]);
  const totalWidth = doc.page.width - 60;
  let colWidths;
  
  if (customWidths) {
    colWidths = customWidths.map(w => totalWidth * w);
  } else {
    const colWidth = totalWidth / cols.length;
    colWidths = cols.map(() => colWidth);
  }
  
  const padding = 3;
  doc.fontSize(6);
  let y = startY;
  
  doc.rect(30, y, totalWidth, 15).stroke();
  let xPos = 30;
  cols.forEach((col, i) => {
    if (i > 0) doc.moveTo(xPos, y).lineTo(xPos, y + 15).stroke();
    doc.text(col, xPos + padding, y + padding, { width: colWidths[i] - 2 * padding, lineBreak: false, ellipsis: true });
    xPos += colWidths[i];
  });
  y += 15;
  
  data.forEach(row => {
    const rowTexts = cols.map(col => String(row[col] || ''));
    let maxHeight = 0;
    
    rowTexts.forEach((text, i) => {
      const height = doc.heightOfString(text, { width: colWidths[i] - 2 * padding });
      if (height > maxHeight) maxHeight = height;
    });
    
    const rowHeight = Math.max(maxHeight + 2 * padding, 12);
    
    doc.rect(30, y, totalWidth, rowHeight).stroke();
    xPos = 30;
    cols.forEach((col, i) => {
      if (i > 0) doc.moveTo(xPos, y).lineTo(xPos, y + rowHeight).stroke();
      doc.text(rowTexts[i], xPos + padding, y + padding, { width: colWidths[i] - 2 * padding });
      xPos += colWidths[i];
    });
    
    y += rowHeight;
  });
  
  return y;
}

async function generateReport() {
  let connection;
  try {
    connection = await mysql.createConnection(dbConfig);
    
    const today = new Date();
    const sixDaysAgo = new Date(today);
    sixDaysAgo.setDate(today.getDate() - 6);
    const dateFilter = sixDaysAgo.toISOString().split('T')[0];
    
    const [lichCN] = await connection.execute(
      'SELECT VITRI, WEEKDAY, START, END, TASK FROM HMGROUP_LichCN WHERE DUAN IN (?, ?)',
      ['Sân bay Nội Bài', 'Sân bay T1 (V2)']
    );
    
    const [taskHistory] = await connection.execute(
      'SELECT NguoiDung, Ngay, Gio, ChiTiet, ChiTiet2, ViTri, PhanLoai, HinhAnh FROM HMGROUP_TaskHistory WHERE BoPhan = ? AND Ngay >= ?',
      ['Sân bay nội bài ga T2', dateFilter]
    );
    
    await connection.end();
    
    const lichCNMapped = lichCN.map(row => ({
      'Vị trí': row.VITRI,
      'Ngày': row.WEEKDAY,
      'Bắt đầu': row.START,
      'Kết thúc': row.END,
      'Mô tả': row.TASK
    }));
    
    const taskHistoryMapped = taskHistory.map(row => ({
      'Tài khoản': row.NguoiDung,
      'Ngày': row.Ngay ? new Date(row.Ngay).toISOString().split('T')[0] : '',
      'Giờ': row.Gio,
      'Chi tiết': row.ChiTiet,
      'Kế hoạch': row.ChiTiet2,
      'Vị trí': row.ViTri,
      'Phân loại': row.PhanLoai,
      'Hình ảnh': (row.HinhAnh && row.HinhAnh !== '') ? 'Có' : 'Không'
    }));
    
    const fileName = `noibaingay${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}.pdf`;
    const filePath = `./document/${fileName}`;
    
    if (!fs.existsSync('./document')) {
      fs.mkdirSync('./document', { recursive: true });
    }
    
    const doc = new PDFDocument({ size: [841.89, 999999], margin: 30 });
    doc.registerFont('Arial', 'arial.ttf');
    doc.font('Arial');
    doc.pipe(fs.createWriteStream(filePath));
    
    doc.fontSize(10).text(FIXED_TEXT_1, { align: 'center' });
    doc.moveDown();
    
    let currentY = doc.y;
    
    if (FIXED_TEXT_2) {
      doc.fontSize(8).text(FIXED_TEXT_2, { width: doc.page.width - 60 });
      doc.moveDown(0.5);
      currentY = doc.y;
    }
    
    currentY = drawTable(doc, lichCNMapped, currentY, [0.1, 0.1, 0.1, 0.1, 0.6]);
    
    doc.y = currentY + 10;
    
    if (FIXED_TEXT_3) {
      doc.fontSize(8).text(FIXED_TEXT_3, { width: doc.page.width - 60 });
      doc.moveDown(0.5);
    }
    
    drawTable(doc, taskHistoryMapped, doc.y);
    
    doc.end();
    console.log(`Report generated: ${filePath}`);
  } catch (error) {
    console.error('Error generating report:', error);
    if (connection) await connection.end();
  }
}

cron.schedule('2,17,32,47 * * * *', generateReport);

generateReport();