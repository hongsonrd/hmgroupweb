const mysql = require('mysql2/promise');
const nodemailer = require('nodemailer');
const fs = require('fs').promises;
const path = require('path');
const dbConfig = require('./dangnhap.js');
const emailConfig = require('./dangnhapemail.js');
class T2ReportGenerator {
async sendT2Report() {
console.log('Đang gửi báo cáo T2 qua email...');
const emailTransporter = nodemailer.createTransporter({
service: 'gmail',
auth: {
user: emailConfig.user,
pass: emailConfig.apppassword
}
});
const mailOptions = {
from: emailConfig.user,
to: T2_REPORT_RECIPIENTS.join(', '),
subject: `Báo cáo ${this.PROJECT_NAME} - ${this.formatDate(this.today, 'dd/mm/yyyy')}`,
html: `<h2>Báo cáo ${this.PROJECT_NAME}</h2><p>Vui lòng xem file đính kèm để biết chi tiết báo cáo ngày ${this.formatDate(this.today, 'dd/mm/yyyy')}</p>`,
attachments: [{
filename: this.reportFilename,
path: this.reportPath,
contentType: 'text/html'
}]
};
await emailTransporter.sendMail(mailOptions);
console.log('Email đã được gửi thành công!');
}
constructor() {
this.connection = null;
this.today = new Date();
this.reportDate = this.formatDate(this.today, 'yyyymmdd');
this.reportFilename = `${this.reportDate}gat2.html`;
this.reportPath = path.join('./drive', this.reportFilename);
this.PROJECT_NAME = 'Sân bay nội bài ga T2';
}
formatDate(date, format = 'yyyy-mm-dd') {
const year = date.getFullYear();
const month = String(date.getMonth() + 1).padStart(2, '0');
const day = String(date.getDate()).padStart(2, '0');
switch(format) {
case 'yyyymmdd': return `${year}${month}${day}`;
case 'dd/mm/yyyy': return `${day}/${month}/${year}`;
default: return `${year}-${month}-${day}`;
}
}
getMonthRange() {
const now = new Date();
const currentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
return { currentMonth: this.formatDate(currentMonth), previousMonth: this.formatDate(previousMonth) };
}
getRobotModel(robotId) {
if (!robotId) return 'Unknown';
const id = robotId.toUpperCase();
if (id.startsWith('GS100') || id.startsWith('GS400')) return 'Model 75';
if (id.startsWith('GS101') || id.startsWith('GS401')) return 'Model 50';
if (id.startsWith('GS142')) return 'Model 40';
if (id.startsWith('GS438')) return 'Model P';
return 'Unknown';
}
parseRobotDetails(chitiet) {
const data = {};
const patterns = {
cnCount: /Số CN sử dụng:\s*([\d.]+)/,
actualArea: /Diện tích sử dụng \(m2\):\s*([\d.]+)/,
plannedArea: /Diện tích kế hoạch:\s*([\d.]+)/,
completion: /Tỉ lệ hoàn thành:\s*([\d.]+)/,
speed: /Tốc độ m2\/giờ:\s*([\d.]+)/,
water: /Lít nước tiêu thụ:\s*([\d.]+)/,
duration: /Thời gian sử dụng \(phút\):\s*([\d.]+)/,
battery: /Lượng pin tiêu thụ:\s*([\d.]+)/
};
Object.entries(patterns).forEach(([key, pattern]) => {
const match = chitiet.match(pattern);
data[key] = match ? parseFloat(match[1]) : 0;
});
return data;
}
calculateStartTime(endTime, areaM2) {
const durationHours = areaM2 / 1000;
const durationMinutes = Math.round(durationHours * 60);
const [hours, minutes, seconds] = endTime.split(':').map(Number);
const endDate = new Date();
endDate.setHours(hours, minutes, seconds || 0);
const startDate = new Date(endDate.getTime() - durationMinutes * 60000);
return startDate.toTimeString().slice(0, 8);
}
async connectDB() {
this.connection = await mysql.createConnection(dbConfig);
}
async getRobotData() {
const { currentMonth, previousMonth } = this.getMonthRange();
const query = `SELECT TaskID, KetQua, Ngay, Gio, ChiTiet, ChiTiet2, ViTri FROM HMGROUP_TaskHistory WHERE BoPhan = ? AND PhanLoai = 'Robot' AND Ngay >= ? ORDER BY Ngay DESC, Gio DESC`;
const [rows] = await this.connection.execute(query, [this.PROJECT_NAME, previousMonth]);
return rows.map(row => {
const parsedData = this.parseRobotDetails(row.ChiTiet || '');
return {
...row,
parsedData,
robotId: row.ChiTiet2,
area: row.ViTri,
model: this.getRobotModel(row.ChiTiet2),
month: new Date(row.Ngay).getMonth() + 1,
day: new Date(row.Ngay).getDate(),
hour: parseInt(row.Gio.split(':')[0]),
startTime: this.calculateStartTime(row.Gio, parsedData.actualArea)
};
});
}
generateDailyComparison(robotData) {
const currentMonth = new Date().getMonth() + 1;
const previousMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const todayDay = new Date().getDate();
const currentData = robotData.filter(r => r.month === currentMonth && r.day <= todayDay);
const previousData = robotData.filter(r => r.month === previousMonth);
const dailyStats = {};
for (let day = 1; day <= todayDay; day++) {
const currentDay = currentData.filter(r => r.day === day);
const previousDay = previousData.filter(r => r.day === day);
if (currentDay.length > 0 || previousDay.length > 0) {
const currentAvgCompletion = currentDay.length > 0 ? currentDay.reduce((sum, r) => sum + r.parsedData.completion, 0) / currentDay.length : 0;
const previousAvgCompletion = previousDay.length > 0 ? previousDay.reduce((sum, r) => sum + r.parsedData.completion, 0) / previousDay.length : 0;
dailyStats[day] = {
current: {
count: currentDay.length,
totalArea: currentDay.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgCompletion: currentAvgCompletion,
totalDuration: currentDay.reduce((sum, r) => sum + r.parsedData.duration, 0),
totalBattery: currentDay.reduce((sum, r) => sum + r.parsedData.battery, 0),
avgPlanned: currentDay.length > 0 ? currentDay.reduce((sum, r) => sum + r.parsedData.plannedArea, 0) / currentDay.length : 0
},
previous: {
count: previousDay.length,
totalArea: previousDay.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgCompletion: previousAvgCompletion,
totalDuration: previousDay.reduce((sum, r) => sum + r.parsedData.duration, 0),
totalBattery: previousDay.reduce((sum, r) => sum + r.parsedData.battery, 0),
avgPlanned: previousDay.length > 0 ? previousDay.reduce((sum, r) => sum + r.parsedData.plannedArea, 0) / previousDay.length : 0
}
};
}
}
return dailyStats;
}
generateHeatmapColor(count, avgCount) {
if (count === 0) return '#f5f5f5';
const threshold = avgCount * 0.5;
const maxThreshold = avgCount * 1.5;
if (count < threshold) return '#f5f5f5';
const normalizedValue = Math.min((count - threshold) / (maxThreshold - threshold), 1);
const r = 255;
const g = Math.round(255 - (normalizedValue * 255));
const b = 0;
return `rgb(${r}, ${g}, ${b})`;
}
generateHourlyHeatmap(robotData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = robotData.filter(r => r.month === currentMonth);
const heatmap = {};
let totalCount = 0;
let cellCount = 0;
for (let day = 1; day <= 31; day++) {
heatmap[day] = {};
for (let hour = 0; hour < 24; hour++) {
const tasks = currentData.filter(r => {
if (r.day !== day) return false;
const startHour = parseInt(r.startTime.split(':')[0]);
const endHour = r.hour;
return hour >= startHour && hour <= endHour;
});
heatmap[day][hour] = {
count: tasks.length,
totalArea: tasks.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgCompletion: tasks.length > 0 ? tasks.reduce((sum, r) => sum + r.parsedData.completion, 0) / tasks.length : 0
};
if (tasks.length > 0) {
totalCount += tasks.length;
cellCount++;
}
}
}
const avgCount = cellCount > 0 ? totalCount / cellCount : 1;
return { heatmap, avgCount };
}
generateHourlyUsage(robotData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = robotData.filter(r => r.month === currentMonth);
const hourlyStats = {};
for (let hour = 0; hour < 24; hour++) {
const hourData = currentData.filter(r => {
const startHour = parseInt(r.startTime.split(':')[0]);
const endHour = r.hour;
return hour >= startHour && hour <= endHour;
});
hourlyStats[hour] = {
count: hourData.length,
totalArea: hourData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgSpeed: hourData.length > 0 ? hourData.reduce((sum, r) => sum + r.parsedData.speed, 0) / hourData.length : 0,
totalWater: hourData.reduce((sum, r) => sum + r.parsedData.water, 0),
totalBattery: hourData.reduce((sum, r) => sum + r.parsedData.battery, 0),
avgCompletion: hourData.length > 0 ? hourData.reduce((sum, r) => sum + r.parsedData.completion, 0) / hourData.length : 0
};
}
return hourlyStats;
}
generateRobotEfficiency(robotData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = robotData.filter(r => r.month === currentMonth && r.robotId);
const robotStats = {};
currentData.forEach(r => {
if (!robotStats[r.robotId]) {
robotStats[r.robotId] = {
robotId: r.robotId,
model: r.model,
count: 0,
totalArea: 0,
avgCompletion: 0,
avgSpeed: 0,
totalBattery: 0,
totalDuration: 0,
tasks: []
};
}
robotStats[r.robotId].count++;
robotStats[r.robotId].totalArea += r.parsedData.actualArea;
robotStats[r.robotId].avgCompletion += r.parsedData.completion;
robotStats[r.robotId].avgSpeed += r.parsedData.speed;
robotStats[r.robotId].totalBattery += r.parsedData.battery;
robotStats[r.robotId].totalDuration += r.parsedData.duration;
robotStats[r.robotId].tasks.push(r);
});
Object.values(robotStats).forEach(stat => {
stat.avgCompletion = stat.avgCompletion / stat.count;
stat.avgSpeed = stat.avgSpeed / stat.count;
stat.avgAreaPerTask = stat.totalArea / stat.count;
stat.efficiency = stat.totalArea / stat.totalBattery;
});
const modelOrder = {'Model 75': 1, 'Model 50': 2, 'Model 40': 3, 'Model P': 4, 'Unknown': 5};
return Object.values(robotStats).sort((a, b) => {
if (modelOrder[a.model] !== modelOrder[b.model]) {
return modelOrder[a.model] - modelOrder[b.model];
}
return b.totalArea - a.totalArea;
});
}
generateMachineryEfficiency(robotData) {
const currentMonth = new Date().getMonth() + 1;
const machineryData = robotData.filter(r => r.month === currentMonth && r.robotId);
const machineStats = {};
machineryData.forEach(r => {
if (!machineStats[r.robotId]) {
machineStats[r.robotId] = {
machineId: r.robotId,
count: 0,
totalArea: 0,
totalDuration: 0,
cleanedCount: 0,
staffPositions: new Set(),
conditions: {},
tasks: []
};
}
machineStats[r.robotId].count++;
machineStats[r.robotId].totalArea += r.parsedData.actualArea;
machineStats[r.robotId].totalDuration += r.parsedData.duration;
if (r.parsedData.cleaned === 'Có') machineStats[r.robotId].cleanedCount++;
machineStats[r.robotId].staffPositions.add(r.area);
const condition = r.parsedData.condition || 'Không rõ';
machineStats[r.robotId].conditions[condition] = (machineStats[r.robotId].conditions[condition] || 0) + 1;
machineStats[r.robotId].tasks.push(r);
});
Object.values(machineStats).forEach(stat => {
stat.avgAreaPerTask = stat.totalArea / stat.count;
stat.avgDuration = stat.totalDuration / stat.count;
stat.cleanedRate = stat.cleanedCount / stat.count;
stat.efficiency = stat.totalArea / stat.totalDuration;
stat.staffPositions = Array.from(stat.staffPositions);
});
return Object.values(machineStats).sort((a, b) => b.totalArea - a.totalArea);
}
generateStaffConsistency(machineryData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = machineryData.filter(r => r.month === currentMonth && r.area);
const staffStats = {};
currentData.forEach(r => {
if (!staffStats[r.area]) {
staffStats[r.area] = {
position: r.area,
count: 0,
machines: new Set(),
totalArea: 0,
cleanedCount: 0,
conditions: {},
avgDuration: 0
};
}
staffStats[r.area].count++;
staffStats[r.area].machines.add(r.robotId);
staffStats[r.area].totalArea += r.parsedData.actualArea;
if (r.parsedData.cleaned === 'Có') staffStats[r.area].cleanedCount++;
staffStats[r.area].avgDuration += r.parsedData.duration;
const condition = r.parsedData.condition || 'Không rõ';
staffStats[r.area].conditions[condition] = (staffStats[r.area].conditions[condition] || 0) + 1;
});
Object.values(staffStats).forEach(stat => {
stat.machineCount = stat.machines.size;
stat.avgDuration = Math.round(stat.avgDuration / stat.count);
stat.cleanedRate = stat.cleanedCount / stat.count;
stat.consistency = stat.cleanedRate >= 0.9 ? 'Cao' : stat.cleanedRate >= 0.7 ? 'Trung bình' : 'Thấp';
delete stat.machines;
});
return Object.values(staffStats).sort((a, b) => b.count - a.count);
}
parseMachineryDetails(chitiet) {
const data = {};
const patterns = {
cnCount: /Số CN sử dụng:\s*([\d.]+)/,
actualArea: /Diện tích sử dụng \(m2\):\s*([\d.]+)/,
cleaned: /Đã vệ sinh:\s*(.+)/,
duration: /Thời gian sử dụng \(phút\):\s*([\d.]+)/,
condition: /Mô tả tình trạng:\s*(.+)/
};
Object.entries(patterns).forEach(([key, pattern]) => {
const match = chitiet.match(pattern);
if (key === 'cleaned' || key === 'condition') {
data[key] = match ? match[1].trim() : '';
} else {
data[key] = match ? parseFloat(match[1]) : 0;
}
});
return data;
}
async getMachineryData() {
const { currentMonth, previousMonth } = this.getMonthRange();
const query = `SELECT TaskID, KetQua, Ngay, Gio, ChiTiet, ChiTiet2, ViTri FROM HMGROUP_TaskHistory WHERE BoPhan = ? AND PhanLoai = 'Máy móc' AND Ngay >= ? ORDER BY Ngay DESC, Gio DESC`;
const [rows] = await this.connection.execute(query, [this.PROJECT_NAME, previousMonth]);
return rows.map(row => {
const parsedData = this.parseMachineryDetails(row.ChiTiet || '');
return {
...row,
parsedData,
robotId: row.ChiTiet2,
area: row.ViTri,
month: new Date(row.Ngay).getMonth() + 1,
day: new Date(row.Ngay).getDate(),
hour: parseInt(row.Gio.split(':')[0]),
startTime: this.calculateStartTime(row.Gio, parsedData.actualArea)
};
});
}
generateMachineryHeatmap(machineryData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = machineryData.filter(r => r.month === currentMonth);
const heatmap = {};
for (let day = 1; day <= 31; day++) {
heatmap[day] = {};
for (let hour = 0; hour < 24; hour++) {
const tasks = currentData.filter(r => {
if (r.day !== day) return false;
const startHour = parseInt(r.startTime.split(':')[0]);
const endHour = r.hour;
return hour >= startHour && hour <= endHour;
});
heatmap[day][hour] = {
count: tasks.length,
totalArea: tasks.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
cleanedCount: tasks.filter(r => r.parsedData.cleaned === 'Có').length
};
}
}
return heatmap;
}
generateMachineryHourlyUsage(machineryData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = machineryData.filter(r => r.month === currentMonth);
const hourlyStats = {};
for (let hour = 0; hour < 24; hour++) {
const hourData = currentData.filter(r => {
const startHour = parseInt(r.startTime.split(':')[0]);
const endHour = r.hour;
return hour >= startHour && hour <= endHour;
});
hourlyStats[hour] = {
count: hourData.length,
totalArea: hourData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgDuration: hourData.length > 0 ? hourData.reduce((sum, r) => sum + r.parsedData.duration, 0) / hourData.length : 0,
cleanedCount: hourData.filter(r => r.parsedData.cleaned === 'Có').length,
cleanedRate: hourData.length > 0 ? hourData.filter(r => r.parsedData.cleaned === 'Có').length / hourData.length : 0
};
}
return hourlyStats;
}
generateMachineryHTMLSection(machineryHeatmap, machineryHourlyUsage, machineryEfficiency, staffConsistency, machineryData, missingMachines) {
const currentMonth = new Date().getMonth() + 1;
return `<div class="section"><div class="section-header"><h2>Báo cáo sử dụng máy móc (Tháng ${currentMonth})</h2></div><div class="section-content"><div class="insight"><div class="insight-title">Chú thích:</div>Báo cáo này theo dõi việc sử dụng máy móc bởi nhân viên. Thời gian bắt đầu ước tính dựa trên diện tích và tốc độ 1000m²/h. Tính nhất quán đánh giá dựa trên tỷ lệ vệ sinh sau sử dụng.</div>${missingMachines.length > 0 ? `<div class="insight" style="background:#ffebee;border-left-color:#f44336"><div class="insight-title" style="color:#c62828">Cảnh báo: Máy chưa có báo cáo hôm nay</div>${missingMachines.join(', ')}</div>` : ''}<h3>Bản đồ nhiệt sử dụng máy móc</h3><div class="heatmap"><div class="heatmap-label"></div>${Array.from({length:24},(_, i) => `<div class="heatmap-label">${i}h</div>`).join('')}${Object.entries(machineryHeatmap).map(([day, hours]) => {
const hasData = Object.values(hours).some(h => h.count > 0);
if (!hasData) return '';
return `<div class="heatmap-label">${day}</div>${Object.entries(hours).map(([hour, data]) => {
if (data.count === 0) return '<div class="heatmap-cell" style="background:#f5f5f5"></div>';
const intensity = Math.min(1, data.count / 3);
const r = 255;
const g = Math.round(255 - (intensity * 100));
const b = Math.round(255 - (intensity * 255));
const color = `rgb(${r}, ${g}, ${b})`;
return `<div class="heatmap-cell" style="background:${color}" data-tooltip="Ngày ${day}, ${hour}h: ${data.count} lần, ${Math.round(data.totalArea)}m², ${data.cleanedCount} đã vệ sinh"></div>`;
}).join('')}`;
}).join('')}</div><h3>Thống kê theo giờ</h3><div class="chart-container"><canvas id="machineryHourlyChart"></canvas></div><table class="table"><thead><tr><th>Giờ</th><th>Số lần</th><th>Diện tích (m²)</th><th>Thời gian TB (phút)</th><th>Đã vệ sinh</th><th>Tỷ lệ vệ sinh</th></tr></thead><tbody>${Object.entries(machineryHourlyUsage).filter(([_, data]) => data.count > 0).map(([hour, data]) => `<tr><td><strong>${hour}:00</strong></td><td>${data.count}</td><td>${Math.round(data.totalArea)}</td><td>${Math.round(data.avgDuration)}</td><td class="${data.cleanedCount === data.count ? 'positive' : data.cleanedCount === 0 ? 'negative' : 'neutral'}">${data.cleanedCount}/${data.count}</td><td class="${data.cleanedRate >= 0.9 ? 'positive' : data.cleanedRate >= 0.7 ? 'neutral' : 'negative'}">${Math.round(data.cleanedRate * 100)}%</td></tr>`).join('')}</tbody></table><h3>Hiệu suất từng máy móc</h3><div class="robot-efficiency-grid">${machineryEfficiency.map(machine => `<div class="robot-card"><h4>${machine.machineId}</h4><p><strong>Số lần sử dụng:</strong> ${machine.count}</p><p><strong>Tổng diện tích:</strong> ${Math.round(machine.totalArea).toLocaleString()} m²</p><p><strong>TB mỗi lần:</strong> ${Math.round(machine.avgAreaPerTask)} m²</p><p><strong>Thời gian TB:</strong> ${Math.round(machine.avgDuration)} phút</p><p><strong>Tỷ lệ vệ sinh:</strong> <span class="${machine.cleanedRate >= 0.9 ? 'positive' : machine.cleanedRate >= 0.7 ? 'neutral' : 'negative'}">${Math.round(machine.cleanedRate * 100)}%</span></p><p><strong>Hiệu suất:</strong> ${Math.round(machine.efficiency * 10) / 10} m²/phút</p><p><strong>Vị trí sử dụng:</strong> ${machine.staffPositions.join(', ')}</p><p><strong>Tình trạng:</strong> ${Object.entries(machine.conditions).map(([cond, count]) => `${cond} (${count})`).join(', ')}</p></div>`).join('')}</div><div class="chart-container"><canvas id="machineryEffChart"></canvas></div><h3>Tính nhất quán theo vị trí nhân viên</h3><table class="table"><thead><tr><th>Vị trí</th><th>Số báo cáo</th><th>Số máy</th><th>Diện tích (m²)</th><th>Thời gian TB</th><th>Tỷ lệ vệ sinh</th><th>Nhất quán</th></tr></thead><tbody>${staffConsistency.map(staff => `<tr><td><strong>${staff.position}</strong></td><td>${staff.count}</td><td>${staff.machineCount}</td><td>${Math.round(staff.totalArea).toLocaleString()}</td><td>${staff.avgDuration}p</td><td class="${staff.cleanedRate >= 0.9 ? 'positive' : staff.cleanedRate >= 0.7 ? 'neutral' : 'negative'}">${Math.round(staff.cleanedRate * 100)}%</td><td class="${staff.consistency === 'Cao' ? 'positive' : staff.consistency === 'Trung bình' ? 'neutral' : 'negative'}">${staff.consistency}</td></tr>`).join('')}</tbody></table><h3>Chi tiết tất cả báo cáo máy móc</h3><table class="table"><thead><tr><th>Ngày</th><th>Thời gian</th><th>Máy</th><th>Vị trí</th><th>Đánh giá</th><th>Diện tích</th><th>Thời gian</th><th>Vệ sinh</th><th>Tình trạng</th></tr></thead><tbody>${machineryData.filter(r => r.month === currentMonth).map(r => `<tr><td>${this.formatDate(new Date(r.Ngay), 'dd/mm/yyyy')}</td><td>${r.startTime} - ${r.Gio}</td><td>${r.robotId || 'N/A'}</td><td>${r.area || 'N/A'}</td><td>${r.KetQua || '-'}</td><td>${Math.round(r.parsedData.actualArea)}m²</td><td>${r.parsedData.duration}p</td><td class="${r.parsedData.cleaned === 'Có' ? 'positive' : 'negative'}">${r.parsedData.cleaned}</td><td>${r.parsedData.condition || '-'}</td></tr>`).join('')}</tbody></table></div></div>`;
}
generateMachineryChartScripts(machineryHourlyUsage, machineryEfficiency) {
return `const machineryHourlyCtx=document.getElementById('machineryHourlyChart').getContext('2d');new Chart(machineryHourlyCtx,{type:'bar',data:{labels:${JSON.stringify(Object.keys(machineryHourlyUsage).filter(h => machineryHourlyUsage[h].count > 0).map(h => h + ':00'))},datasets:[{label:'Số lần sử dụng',data:${JSON.stringify(Object.values(machineryHourlyUsage).filter(h => h.count > 0).map(h => h.count))},backgroundColor:'rgba(54,162,235,0.8)',yAxisID:'y'},{label:'Diện tích (m²)',data:${JSON.stringify(Object.values(machineryHourlyUsage).filter(h => h.count > 0).map(h => Math.round(h.totalArea)))},backgroundColor:'rgba(255,99,132,0.8)',yAxisID:'y1'},{label:'Tỷ lệ vệ sinh (%)',data:${JSON.stringify(Object.values(machineryHourlyUsage).filter(h => h.count > 0).map(h => Math.round(h.cleanedRate * 100)))},backgroundColor:'rgba(75,192,192,0.8)',type:'line',yAxisID:'y2',borderColor:'rgba(75,192,192,1)',tension:0.4}]},options:{responsive:true,maintainAspectRatio:false,scales:{y:{type:'linear',position:'left',title:{display:true,text:'Số lần'}},y1:{type:'linear',position:'right',title:{display:true,text:'Diện tích (m²)'},grid:{drawOnChartArea:false}},y2:{type:'linear',position:'right',title:{display:true,text:'Tỷ lệ vệ sinh (%)'},grid:{drawOnChartArea:false},max:100}}}});const machineryEffCtx=document.getElementById('machineryEffChart').getContext('2d');new Chart(machineryEffCtx,{type:'bar',data:{labels:${JSON.stringify(machineryEfficiency.map(m => m.machineId))},datasets:[{label:'Tổng diện tích (m²)',data:${JSON.stringify(machineryEfficiency.map(m => Math.round(m.totalArea)))},backgroundColor:'rgba(255,99,132,0.8)',yAxisID:'y'},{label:'Tỷ lệ vệ sinh (%)',data:${JSON.stringify(machineryEfficiency.map(m => Math.round(m.cleanedRate * 100)))},backgroundColor:'rgba(75,192,192,0.8)',type:'line',yAxisID:'y1',borderColor:'rgba(75,192,192,1)',tension:0.4}]},options:{responsive:true,maintainAspectRatio:false,indexAxis:'y',scales:{x:{title:{display:true,text:'Diện tích (m²)'}},y:{beginAtZero:true},y1:{type:'linear',position:'right',title:{display:true,text:'Tỷ lệ vệ sinh (%)'},grid:{drawOnChartArea:false},max:100}}}});`;
}
parseQualityCheckSchedule(chitiet2) {
if (!chitiet2 || !chitiet2.includes('-')) return null;
const parts = chitiet2.split('-');
if (parts.length < 3) return null;
return {
startTime: parts[0].trim(),
endTime: parts[1].trim(),
detail: parts.slice(2).join('-').trim()
};
}
async getStaffQualityData() {
const { currentMonth, previousMonth } = this.getMonthRange();
const query = `SELECT TaskID, NguoiDung, KetQua, Ngay, Gio, ChiTiet, ChiTiet2, ViTri, PhanLoai, HinhAnh FROM HMGROUP_TaskHistory WHERE BoPhan = ? AND PhanLoai <> 'Robot' AND Ngay >= ? ORDER BY Ngay DESC, Gio DESC`;
const [rows] = await this.connection.execute(query, [this.PROJECT_NAME, previousMonth]);
return rows.map(row => {
const schedule = row.PhanLoai === 'Kiểm tra chất lượng' ? this.parseQualityCheckSchedule(row.ChiTiet2) : null;
let timeStatus = null;
if (schedule && schedule.endTime) {
const scheduledEnd = schedule.endTime;
const actualEnd = row.Gio;
const scheduledMinutes = parseInt(scheduledEnd.split(':')[0]) * 60 + parseInt(scheduledEnd.split(':')[1]);
const actualMinutes = parseInt(actualEnd.split(':')[0]) * 60 + parseInt(actualEnd.split(':')[1]);
const diff = actualMinutes - scheduledMinutes;
if (diff < -5) timeStatus = 'early';
else if (diff > 5) timeStatus = 'late';
else timeStatus = 'ontime';
}
return {
...row,
schedule,
timeStatus,
month: new Date(row.Ngay).getMonth() + 1,
day: new Date(row.Ngay).getDate(),
hour: parseInt(row.Gio.split(':')[0])
};
});
}
generateStaffQualityHeatmap(staffData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = staffData.filter(r => r.month === currentMonth);
const heatmap = {};
for (let day = 1; day <= 31; day++) {
heatmap[day] = {};
for (let hour = 0; hour < 24; hour++) {
const tasks = currentData.filter(r => r.day === day && r.hour === hour);
heatmap[day][hour] = {
count: tasks.length,
withImage: tasks.filter(r => r.HinhAnh).length,
ontime: tasks.filter(r => r.timeStatus === 'ontime').length
};
}
}
return heatmap;
}
generatePositionConsistency(staffData) {
const currentMonth = new Date().getMonth() + 1;
const todayDay = new Date().getDate();
const currentData = staffData.filter(r => r.month === currentMonth);
const todayData = currentData.filter(r => r.day === todayDay);
const positionStats = {};
currentData.forEach(r => {
if (!r.ViTri) return;
if (!positionStats[r.ViTri]) {
positionStats[r.ViTri] = {
position: r.ViTri,
count: 0,
staff: new Set(),
reportTypes: {},
withImage: 0,
ontimeCount: 0,
lateCount: 0,
earlyCount: 0,
resultCategories: {}
};
}
positionStats[r.ViTri].count++;
positionStats[r.ViTri].staff.add(r.NguoiDung);
positionStats[r.ViTri].reportTypes[r.PhanLoai] = (positionStats[r.ViTri].reportTypes[r.PhanLoai] || 0) + 1;
if (r.HinhAnh) positionStats[r.ViTri].withImage++;
if (r.timeStatus === 'ontime') positionStats[r.ViTri].ontimeCount++;
if (r.timeStatus === 'late') positionStats[r.ViTri].lateCount++;
if (r.timeStatus === 'early') positionStats[r.ViTri].earlyCount++;
if (r.KetQua) positionStats[r.ViTri].resultCategories[r.KetQua] = (positionStats[r.ViTri].resultCategories[r.KetQua] || 0) + 1;
});
const todayPositions = new Set(todayData.map(r => r.ViTri).filter(Boolean));
const allPositions = new Set(currentData.map(r => r.ViTri).filter(Boolean));
const missingPositions = Array.from(allPositions).filter(pos => !todayPositions.has(pos));
Object.values(positionStats).forEach(stat => {
stat.staffCount = stat.staff.size;
stat.imageRate = stat.withImage / stat.count;
stat.ontimeRate = stat.ontimeCount / (stat.ontimeCount + stat.lateCount + stat.earlyCount || 1);
stat.consistency = stat.ontimeRate >= 0.9 ? 'Cao' : stat.ontimeRate >= 0.7 ? 'Trung bình' : 'Thấp';
delete stat.staff;
});
return {
stats: Object.values(positionStats).sort((a, b) => b.count - a.count),
missingPositions
};
}
generateResultConsistency(staffData) {
const currentMonth = new Date().getMonth() + 1;
const currentData = staffData.filter(r => r.month === currentMonth && r.KetQua);
const resultStats = {};
currentData.forEach(r => {
if (!resultStats[r.KetQua]) {
resultStats[r.KetQua] = {
result: r.KetQua,
count: 0,
positions: new Set(),
reportTypes: {},
withImage: 0,
ontimeCount: 0
};
}
resultStats[r.KetQua].count++;
if (r.ViTri) resultStats[r.KetQua].positions.add(r.ViTri);
resultStats[r.KetQua].reportTypes[r.PhanLoai] = (resultStats[r.KetQua].reportTypes[r.PhanLoai] || 0) + 1;
if (r.HinhAnh) resultStats[r.KetQua].withImage++;
if (r.timeStatus === 'ontime') resultStats[r.KetQua].ontimeCount++;
});
Object.values(resultStats).forEach(stat => {
stat.positionCount = stat.positions.size;
stat.imageRate = stat.withImage / stat.count;
stat.ontimeRate = stat.ontimeCount / stat.count;
delete stat.positions;
});
return Object.values(resultStats).sort((a, b) => b.count - a.count);
}
getMissingMachinesToday(machineryData) {
const currentMonth = new Date().getMonth() + 1;
const todayDay = new Date().getDate();
const currentData = machineryData.filter(r => r.month === currentMonth && r.robotId);
const todayData = currentData.filter(r => r.day === todayDay);
const allMachines = new Set(currentData.map(r => r.robotId));
const todayMachines = new Set(todayData.map(r => r.robotId));
return Array.from(allMachines).filter(m => !todayMachines.has(m));
}
generateStaffQualityHTMLSection(staffHeatmap, positionConsistency, resultConsistency, staffData) {
const currentMonth = new Date().getMonth() + 1;
return `<div class="section"><div class="section-header"><h2>Báo cáo chất lượng nhân viên (Tháng ${currentMonth})</h2></div><div class="section-content"><div class="insight"><div class="insight-title">Chú thích:</div>Báo cáo này theo dõi hoạt động kiểm tra chất lượng và các báo cáo khác của nhân viên. Trạng thái thời gian: Đúng giờ (±5 phút), Sớm (>5 phút trước), Trễ (>5 phút sau). Tính nhất quán đánh giá dựa trên tỷ lệ báo cáo đúng giờ.</div>${positionConsistency.missingPositions.length > 0 ? `<div class="insight" style="background:#ffebee;border-left-color:#f44336"><div class="insight-title" style="color:#c62828">Cảnh báo: Vị trí chưa có báo cáo hôm nay</div>${positionConsistency.missingPositions.join(', ')}</div>` : ''}<h3>Bản đồ nhiệt hoạt động nhân viên</h3><div class="heatmap"><div class="heatmap-label"></div>${Array.from({length:24},(_, i) => `<div class="heatmap-label">${i}h</div>`).join('')}${Object.entries(staffHeatmap).map(([day, hours]) => {
const hasData = Object.values(hours).some(h => h.count > 0);
if (!hasData) return '';
return `<div class="heatmap-label">${day}</div>${Object.entries(hours).map(([hour, data]) => {
if (data.count === 0) return '<div class="heatmap-cell" style="background:#f5f5f5"></div>';
const intensity = Math.min(1, data.count / 5);
const r = 255;
const g = Math.round(255 - (intensity * 100));
const b = Math.round(255 - (intensity * 255));
const color = `rgb(${r}, ${g}, ${b})`;
return `<div class="heatmap-cell" style="background:${color}" data-tooltip="Ngày ${day}, ${hour}h: ${data.count} báo cáo, ${data.withImage} có ảnh, ${data.ontime} đúng giờ"></div>`;
}).join('')}`;
}).join('')}</div><h3>Tính nhất quán theo vị trí</h3><table class="table"><thead><tr><th>Vị trí</th><th>Số báo cáo</th><th>Số nhân viên</th><th>Có hình ảnh</th><th>Đúng giờ</th><th>Trễ</th><th>Sớm</th><th>Tỷ lệ đúng giờ</th><th>Nhất quán</th></tr></thead><tbody>${positionConsistency.stats.map(stat => `<tr><td><strong>${stat.position}</strong></td><td>${stat.count}</td><td>${stat.staffCount}</td><td class="${stat.imageRate >= 0.8 ? 'positive' : stat.imageRate >= 0.5 ? 'neutral' : 'negative'}">${stat.withImage} (${Math.round(stat.imageRate * 100)}%)</td><td class="positive">${stat.ontimeCount}</td><td class="negative">${stat.lateCount}</td><td class="neutral">${stat.earlyCount}</td><td class="${stat.ontimeRate >= 0.9 ? 'positive' : stat.ontimeRate >= 0.7 ? 'neutral' : 'negative'}">${Math.round(stat.ontimeRate * 100)}%</td><td class="${stat.consistency === 'Cao' ? 'positive' : stat.consistency === 'Trung bình' ? 'neutral' : 'negative'}">${stat.consistency}</td></tr>`).join('')}</tbody></table><div class="chart-container"><canvas id="positionConsistencyChart"></canvas></div><h3>Phân tích theo kết quả</h3><table class="table"><thead><tr><th>Kết quả</th><th>Số lượng</th><th>Số vị trí</th><th>Có hình ảnh</th><th>Tỷ lệ đúng giờ</th></tr></thead><tbody>${resultConsistency.map(stat => `<tr><td><strong>${stat.result}</strong></td><td>${stat.count}</td><td>${stat.positionCount}</td><td class="${stat.imageRate >= 0.8 ? 'positive' : stat.imageRate >= 0.5 ? 'neutral' : 'negative'}">${stat.withImage} (${Math.round(stat.imageRate * 100)}%)</td><td class="${stat.ontimeRate >= 0.9 ? 'positive' : stat.ontimeRate >= 0.7 ? 'neutral' : 'negative'}">${Math.round(stat.ontimeRate * 100)}%</td></tr>`).join('')}</tbody></table><div class="chart-container"><canvas id="resultConsistencyChart"></canvas></div><h3>Chi tiết báo cáo nhân viên</h3><table class="table"><thead><tr><th>Ngày</th><th>Giờ</th><th>Nhân viên</th><th>Vị trí</th><th>Loại</th><th>Kết quả</th><th>Thời gian</th><th>Chi tiết</th><th>Hình ảnh</th></tr></thead><tbody>${staffData.filter(r => r.month === currentMonth).map(r => {
const timeClass = r.timeStatus === 'ontime' ? 'positive' : r.timeStatus === 'late' ? 'negative' : r.timeStatus === 'early' ? 'neutral' : '';
const timeText = r.timeStatus === 'ontime' ? 'Đúng giờ' : r.timeStatus === 'late' ? 'Trễ' : r.timeStatus === 'early' ? 'Sớm' : '-';
return `<tr><td>${this.formatDate(new Date(r.Ngay), 'dd/mm/yyyy')}</td><td>${r.Gio}</td><td>${r.NguoiDung}</td><td>${r.ViTri || '-'}</td><td>${r.PhanLoai}</td><td>${r.KetQua || '-'}</td><td class="${timeClass}">${r.schedule ? `${r.schedule.startTime}-${r.schedule.endTime}<br>${timeText}` : '-'}</td><td>${r.ChiTiet || '-'}</td><td>${r.HinhAnh ? '<span class="positive">Có</span>' : '<span class="negative">Không</span>'}</td></tr>`;
}).join('')}</tbody></table></div></div>`;
}
generateStaffQualityChartScripts(positionConsistency, resultConsistency) {
return `const positionCtx=document.getElementById('positionConsistencyChart').getContext('2d');new Chart(positionCtx,{type:'bar',data:{labels:${JSON.stringify(positionConsistency.stats.map(s => s.position))},datasets:[{label:'Số báo cáo',data:${JSON.stringify(positionConsistency.stats.map(s => s.count))},backgroundColor:'rgba(54,162,235,0.8)',yAxisID:'y'},{label:'Tỷ lệ đúng giờ (%)',data:${JSON.stringify(positionConsistency.stats.map(s => Math.round(s.ontimeRate * 100)))},backgroundColor:'rgba(75,192,192,0.8)',type:'line',yAxisID:'y1',borderColor:'rgba(75,192,192,1)',tension:0.4}]},options:{responsive:true,maintainAspectRatio:false,indexAxis:'y',scales:{x:{title:{display:true,text:'Số báo cáo'}},y:{beginAtZero:true},y1:{type:'linear',position:'right',title:{display:true,text:'Tỷ lệ đúng giờ (%)'},grid:{drawOnChartArea:false},max:100}}}});const resultCtx=document.getElementById('resultConsistencyChart').getContext('2d');new Chart(resultCtx,{type:'doughnut',data:{labels:${JSON.stringify(resultConsistency.map(s => s.result))},datasets:[{data:${JSON.stringify(resultConsistency.map(s => s.count))},backgroundColor:['rgba(255,99,132,0.8)','rgba(54,162,235,0.8)','rgba(255,206,86,0.8)','rgba(75,192,192,0.8)','rgba(153,102,255,0.8)','rgba(255,159,64,0.8)']}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'right'}}}});`;
}
calculateMonthlyRobotStats(robotData) {
const currentMonth = new Date().getMonth() + 1;
const previousMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const currentData = robotData.filter(r => r.month === currentMonth);
const previousData = robotData.filter(r => r.month === previousMonth);
const dailyBreakdown = {};
for (let day = 1; day <= 31; day++) {
const dayData = currentData.filter(r => r.day === day);
if (dayData.length > 0) {
dailyBreakdown[day] = {
count: dayData.length,
totalArea: dayData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgCompletion: dayData.reduce((sum, r) => sum + r.parsedData.completion, 0) / dayData.length,
totalBattery: dayData.reduce((sum, r) => sum + r.parsedData.battery, 0),
totalDuration: dayData.reduce((sum, r) => sum + r.parsedData.duration, 0)
};
}
}
const modelStats = {};
currentData.forEach(r => {
if (!modelStats[r.model]) {
modelStats[r.model] = {
count: 0,
totalArea: 0,
avgCompletion: 0,
totalBattery: 0,
avgSpeed: 0
};
}
modelStats[r.model].count++;
modelStats[r.model].totalArea += r.parsedData.actualArea;
modelStats[r.model].avgCompletion += r.parsedData.completion;
modelStats[r.model].totalBattery += r.parsedData.battery;
modelStats[r.model].avgSpeed += r.parsedData.speed;
});
Object.values(modelStats).forEach(stat => {
stat.avgCompletion = stat.avgCompletion / stat.count;
stat.avgSpeed = stat.avgSpeed / stat.count;
});
const areaStats = {};
currentData.forEach(r => {
if (r.area) {
if (!areaStats[r.area]) {
areaStats[r.area] = {
count: 0,
totalArea: 0,
robots: new Set()
};
}
areaStats[r.area].count++;
areaStats[r.area].totalArea += r.parsedData.actualArea;
areaStats[r.area].robots.add(r.robotId);
}
});
Object.values(areaStats).forEach(stat => {
stat.robotCount = stat.robots.size;
delete stat.robots;
});
return {
totalTasks: currentData.length,
totalArea: currentData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgCompletion: currentData.length > 0 ? currentData.reduce((sum, r) => sum + r.parsedData.completion, 0) / currentData.length : 0,
avgSpeed: currentData.length > 0 ? currentData.reduce((sum, r) => sum + r.parsedData.speed, 0) / currentData.length : 0,
totalBattery: currentData.reduce((sum, r) => sum + r.parsedData.battery, 0),
totalDuration: currentData.reduce((sum, r) => sum + r.parsedData.duration, 0),
uniqueRobots: new Set(currentData.map(r => r.robotId)).size,
dailyBreakdown,
modelStats,
areaStats: Object.entries(areaStats).map(([area, stats]) => ({area, ...stats})).sort((a, b) => b.totalArea - a.totalArea),
previousMonth: {
totalTasks: previousData.length,
totalArea: previousData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgCompletion: previousData.length > 0 ? previousData.reduce((sum, r) => sum + r.parsedData.completion, 0) / previousData.length : 0
}
};
}
calculateMonthlyMachineryStats(machineryData) {
const currentMonth = new Date().getMonth() + 1;
const previousMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const currentData = machineryData.filter(r => r.month === currentMonth);
const previousData = machineryData.filter(r => r.month === previousMonth);
const dailyBreakdown = {};
for (let day = 1; day <= 31; day++) {
const dayData = currentData.filter(r => r.day === day);
if (dayData.length > 0) {
dailyBreakdown[day] = {
count: dayData.length,
totalArea: dayData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
cleanedCount: dayData.filter(r => r.parsedData.cleaned === 'Có').length,
cleanedRate: dayData.filter(r => r.parsedData.cleaned === 'Có').length / dayData.length
};
}
}
return {
totalUsages: currentData.length,
totalArea: currentData.reduce((sum, r) => sum + r.parsedData.actualArea, 0),
avgDuration: currentData.length > 0 ? currentData.reduce((sum, r) => sum + r.parsedData.duration, 0) / currentData.length : 0,
cleanedCount: currentData.filter(r => r.parsedData.cleaned === 'Có').length,
cleanedRate: currentData.length > 0 ? currentData.filter(r => r.parsedData.cleaned === 'Có').length / currentData.length : 0,
uniqueMachines: new Set(currentData.map(r => r.robotId)).size,
dailyBreakdown,
previousMonth: {
totalUsages: previousData.length,
cleanedRate: previousData.length > 0 ? previousData.filter(r => r.parsedData.cleaned === 'Có').length / previousData.length : 0
}
};
}
calculateMonthlyStaffStats(staffData) {
const currentMonth = new Date().getMonth() + 1;
const previousMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const currentData = staffData.filter(r => r.month === currentMonth);
const previousData = staffData.filter(r => r.month === previousMonth);
const dailyBreakdown = {};
for (let day = 1; day <= 31; day++) {
const dayData = currentData.filter(r => r.day === day);
if (dayData.length > 0) {
dailyBreakdown[day] = {
count: dayData.length,
withImage: dayData.filter(r => r.HinhAnh).length,
ontime: dayData.filter(r => r.timeStatus === 'ontime').length,
ontimeRate: dayData.filter(r => r.timeStatus).length > 0 ? dayData.filter(r => r.timeStatus === 'ontime').length / dayData.filter(r => r.timeStatus).length : 0
};
}
}
const staffPerformance = {};
currentData.forEach(r => {
if (r.NguoiDung) {
if (!staffPerformance[r.NguoiDung]) {
staffPerformance[r.NguoiDung] = {
count: 0,
withImage: 0,
ontime: 0,
late: 0,
early: 0,
positions: new Set()
};
}
staffPerformance[r.NguoiDung].count++;
if (r.HinhAnh) staffPerformance[r.NguoiDung].withImage++;
if (r.timeStatus === 'ontime') staffPerformance[r.NguoiDung].ontime++;
if (r.timeStatus === 'late') staffPerformance[r.NguoiDung].late++;
if (r.timeStatus === 'early') staffPerformance[r.NguoiDung].early++;
if (r.ViTri) staffPerformance[r.NguoiDung].positions.add(r.ViTri);
}
});
Object.values(staffPerformance).forEach(stat => {
stat.imageRate = stat.withImage / stat.count;
stat.ontimeRate = stat.ontime / (stat.ontime + stat.late + stat.early || 1);
stat.positionCount = stat.positions.size;
delete stat.positions;
});
return {
totalReports: currentData.length,
imageRate: currentData.length > 0 ? currentData.filter(r => r.HinhAnh).length / currentData.length : 0,
ontimeRate: currentData.filter(r => r.timeStatus).length > 0 ? currentData.filter(r => r.timeStatus === 'ontime').length / currentData.filter(r => r.timeStatus).length : 0,
uniqueStaff: new Set(currentData.map(r => r.NguoiDung)).size,
uniquePositions: new Set(currentData.map(r => r.ViTri).filter(Boolean)).size,
dailyBreakdown,
staffPerformance: Object.entries(staffPerformance).map(([name, stats]) => ({name, ...stats})).sort((a, b) => b.count - a.count),
previousMonth: {
totalReports: previousData.length,
ontimeRate: previousData.filter(r => r.timeStatus).length > 0 ? previousData.filter(r => r.timeStatus === 'ontime').length / previousData.filter(r => r.timeStatus).length : 0
}
};
}
generateMonthlySummaryHTML(robotStats, machineryStats, staffStats) {
const currentMonth = new Date().getMonth() + 1;
const robotChange = robotStats.previousMonth.totalTasks > 0 ? ((robotStats.totalTasks - robotStats.previousMonth.totalTasks) / robotStats.previousMonth.totalTasks * 100).toFixed(1) : 0;
const machineryChange = machineryStats.previousMonth.totalUsages > 0 ? ((machineryStats.totalUsages - machineryStats.previousMonth.totalUsages) / machineryStats.previousMonth.totalUsages * 100).toFixed(1) : 0;
const staffChange = staffStats.previousMonth.totalReports > 0 ? ((staffStats.totalReports - staffStats.previousMonth.totalReports) / staffStats.previousMonth.totalReports * 100).toFixed(1) : 0;
return `<div class="section"><div class="section-header"><h2>Tổng quan tháng ${currentMonth}</h2></div><div class="section-content"><div class="stats-grid"><div class="stat-card"><div class="stat-number">${robotStats.totalTasks}</div><div class="stat-label">Lần robot hoạt động</div><div class="stat-change ${robotChange >= 0 ? 'positive' : 'negative'}">${robotChange >= 0 ? '+' : ''}${robotChange}% so tháng trước</div></div><div class="stat-card"><div class="stat-number">${Math.round(robotStats.totalArea).toLocaleString()}</div><div class="stat-label">Tổng diện tích (m²)</div></div><div class="stat-card"><div class="stat-number">${Math.round(robotStats.avgCompletion * 100)}%</div><div class="stat-label">Hoàn thành TB</div></div><div class="stat-card"><div class="stat-number">${robotStats.uniqueRobots}</div><div class="stat-label">Số robot hoạt động</div></div></div><h3>Xu hướng hoạt động theo ngày</h3><div class="chart-container"><canvas id="monthlyTrendChart"></canvas></div><h3>So sánh theo model robot</h3><div class="chart-container"><canvas id="modelComparisonChart"></canvas></div><h3>Phân bố theo khu vực</h3><div class="chart-container"><canvas id="areaDistributionChart"></canvas></div><table class="table"><thead><tr><th>Khu vực</th><th>Số lần</th><th>Tổng diện tích (m²)</th><th>Số robot</th><th>TB mỗi lần (m²)</th></tr></thead><tbody>${robotStats.areaStats.map(area => `<tr><td><strong>${area.area}</strong></td><td>${area.count}</td><td>${Math.round(area.totalArea).toLocaleString()}</td><td>${area.robotCount}</td><td>${Math.round(area.totalArea / area.count)}</td></tr>`).join('')}</tbody></table></div></div><div class="section"><div class="section-header"><h2>Máy móc - Tháng ${currentMonth}</h2></div><div class="section-content"><div class="stats-grid"><div class="stat-card"><div class="stat-number">${machineryStats.totalUsages}</div><div class="stat-label">Lần sử dụng</div><div class="stat-change ${machineryChange >= 0 ? 'positive' : 'negative'}">${machineryChange >= 0 ? '+' : ''}${machineryChange}% so tháng trước</div></div><div class="stat-card"><div class="stat-number">${Math.round(machineryStats.cleanedRate * 100)}%</div><div class="stat-label">Tỷ lệ vệ sinh</div></div><div class="statnumber">${machineryStats.uniqueMachines}</div><div class="stat-label">Số máy hoạt động</div></div><div class="stat-card"><div class="stat-number">${Math.round(machineryStats.totalArea).toLocaleString()}</div><div class="stat-label">Tổng diện tích (m²)</div></div></div><h3>Xu hướng vệ sinh theo ngày</h3><div class="chart-container"><canvas id="machineryTrendChart"></canvas></div><h3>Hiệu suất vệ sinh hàng ngày</h3><div class="chart-container"><canvas id="machineryCleanedChart"></canvas></div></div></div><div class="section"><div class="section-header"><h2>Nhân viên - Tháng ${currentMonth}</h2></div><div class="section-content"><div class="stats-grid"><div class="stat-card"><div class="stat-number">${staffStats.totalReports}</div><div class="stat-label">Tổng báo cáo</div><div class="stat-change ${staffChange >= 0 ? 'positive' : 'negative'}">${staffChange >= 0 ? '+' : ''}${staffChange}% so tháng trước</div></div><div class="stat-card"><div class="stat-number">${Math.round(staffStats.ontimeRate * 100)}%</div><div class="stat-label">Tỷ lệ đúng giờ</div></div><div class="stat-card"><div class="stat-number">${Math.round(staffStats.imageRate * 100)}%</div><div class="stat-label">Tỷ lệ có hình ảnh</div></div><div class="stat-card"><div class="stat-number">${staffStats.uniqueStaff}</div><div class="stat-label">Số nhân viên</div></div></div><h3>Xu hướng báo cáo theo ngày</h3><div class="chart-container"><canvas id="staffTrendChart"></canvas></div><h3>Hiệu suất nhân viên</h3><div class="chart-container"><canvas id="staffPerformanceChart"></canvas></div><table class="table"><thead><tr><th>Nhân viên</th><th>Số báo cáo</th><th>Tỷ lệ có ảnh</th><th>Tỷ lệ đúng giờ</th><th>Đúng giờ</th><th>Trễ</th><th>Sớm</th><th>Số vị trí</th></tr></thead><tbody>${staffStats.staffPerformance.map(staff => `<tr><td><strong>${staff.name}</strong></td><td>${staff.count}</td><td class="${staff.imageRate >= 0.8 ? 'positive' : staff.imageRate >= 0.5 ? 'neutral' : 'negative'}">${Math.round(staff.imageRate * 100)}%</td><td class="${staff.ontimeRate >= 0.9 ? 'positive' : staff.ontimeRate >= 0.7 ? 'neutral' : 'negative'}">${Math.round(staff.ontimeRate * 100)}%</td><td class="positive">${staff.ontime}</td><td class="negative">${staff.late}</td><td class="neutral">${staff.early}</td><td>${staff.positionCount}</td></tr>`).join('')}</tbody></table></div></div>`;
}
generateMonthlyChartScripts(robotStats, machineryStats, staffStats) {
return `const monthlyTrendCtx=document.getElementById('monthlyTrendChart');if(monthlyTrendCtx){const dailyData=${JSON.stringify(robotStats.dailyBreakdown)};const days=Object.keys(dailyData).sort((a,b)=>a-b);new Chart(monthlyTrendCtx.getContext('2d'),{type:'line',data:{labels:days.map(d=>'Ngày '+d),datasets:[{label:'Số lần hoạt động',data:days.map(d=>dailyData[d].count),borderColor:'rgba(54,162,235,1)',backgroundColor:'rgba(54,162,235,0.2)',tension:0.4,fill:true},{label:'Diện tích (x100 m²)',data:days.map(d=>Math.round(dailyData[d].totalArea/100)),borderColor:'rgba(255,99,132,1)',backgroundColor:'rgba(255,99,132,0.2)',tension:0.4,yAxisID:'y1',fill:true},{label:'Hoàn thành (%)',data:days.map(d=>Math.round(dailyData[d].avgCompletion*100)),borderColor:'rgba(75,192,192,1)',backgroundColor:'rgba(75,192,192,0.2)',tension:0.4,yAxisID:'y2',fill:false}]},options:{responsive:true,maintainAspectRatio:false,interaction:{mode:'index',intersect:false},scales:{y:{type:'linear',position:'left',title:{display:true,text:'Số lần'}},y1:{type:'linear',position:'right',title:{display:true,text:'Diện tích (x100 m²)'},grid:{drawOnChartArea:false}},y2:{type:'linear',position:'right',title:{display:true,text:'Hoàn thành (%)'},grid:{drawOnChartArea:false},max:100}}}});}
const modelCompCtx=document.getElementById('modelComparisonChart');if(modelCompCtx){const modelData=${JSON.stringify(robotStats.modelStats)};const models=Object.keys(modelData);new Chart(modelCompCtx.getContext('2d'),{type:'bar',data:{labels:models,datasets:[{label:'Số lần hoạt động',data:models.map(m=>modelData[m].count),backgroundColor:'rgba(54,162,235,0.8)'},{label:'Diện tích (x100 m²)',data:models.map(m=>Math.round(modelData[m].totalArea/100)),backgroundColor:'rgba(255,99,132,0.8)'},{label:'Hoàn thành TB (%)',data:models.map(m=>Math.round(modelData[m].avgCompletion*100)),backgroundColor:'rgba(75,192,192,0.8)'}]},options:{responsive:true,maintainAspectRatio:false}});}
const areaDistCtx=document.getElementById('areaDistributionChart');if(areaDistCtx){const areaData=${JSON.stringify(robotStats.areaStats)};new Chart(areaDistCtx.getContext('2d'),{type:'doughnut',data:{labels:areaData.map(a=>a.area),datasets:[{data:areaData.map(a=>Math.round(a.totalArea)),backgroundColor:['rgba(255,99,132,0.8)','rgba(54,162,235,0.8)','rgba(255,206,86,0.8)','rgba(75,192,192,0.8)','rgba(153,102,255,0.8)','rgba(255,159,64,0.8)','rgba(201,203,207,0.8)','rgba(255,140,0,0.8)']}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'right'},tooltip:{callbacks:{label:function(ctx){return ctx.label+': '+ctx.parsed.toLocaleString()+' m²';}}}}});}
const machineryTrendCtx=document.getElementById('machineryTrendChart');if(machineryTrendCtx){const dailyData=${JSON.stringify(machineryStats.dailyBreakdown)};const days=Object.keys(dailyData).sort((a,b)=>a-b);new Chart(machineryTrendCtx.getContext('2d'),{type:'line',data:{labels:days.map(d=>'Ngày '+d),datasets:[{label:'Số lần sử dụng',data:days.map(d=>dailyData[d].count),borderColor:'rgba(54,162,235,1)',backgroundColor:'rgba(54,162,235,0.2)',tension:0.4,fill:true},{label:'Diện tích (x100 m²)',data:days.map(d=>Math.round(dailyData[d].totalArea/100)),borderColor:'rgba(255,99,132,1)',backgroundColor:'rgba(255,99,132,0.2)',tension:0.4,yAxisID:'y1',fill:true}]},options:{responsive:true,maintainAspectRatio:false,scales:{y:{type:'linear',position:'left',title:{display:true,text:'Số lần'}},y1:{type:'linear',position:'right',title:{display:true,text:'Diện tích (x100 m²)'},grid:{drawOnChartArea:false}}}}});}
const machineryCleanedCtx=document.getElementById('machineryCleanedChart');if(machineryCleanedCtx){const dailyData=${JSON.stringify(machineryStats.dailyBreakdown)};const days=Object.keys(dailyData).sort((a,b)=>a-b);new Chart(machineryCleanedCtx.getContext('2d'),{type:'bar',data:{labels:days.map(d=>'Ngày '+d),datasets:[{label:'Đã vệ sinh',data:days.map(d=>dailyData[d].cleanedCount),backgroundColor:'rgba(75,192,192,0.8)'},{label:'Chưa vệ sinh',data:days.map(d=>dailyData[d].count-dailyData[d].cleanedCount),backgroundColor:'rgba(255,99,132,0.8)'}]},options:{responsive:true,maintainAspectRatio:false,scales:{x:{stacked:true},y:{stacked:true,title:{display:true,text:'Số lần'}}}}});}
const staffTrendCtx=document.getElementById('staffTrendChart');if(staffTrendCtx){const dailyData=${JSON.stringify(staffStats.dailyBreakdown)};const days=Object.keys(dailyData).sort((a,b)=>a-b);new Chart(staffTrendCtx.getContext('2d'),{type:'line',data:{labels:days.map(d=>'Ngày '+d),datasets:[{label:'Số báo cáo',data:days.map(d=>dailyData[d].count),borderColor:'rgba(54,162,235,1)',backgroundColor:'rgba(54,162,235,0.2)',tension:0.4,fill:true},{label:'Có hình ảnh',data:days.map(d=>dailyData[d].withImage),borderColor:'rgba(255,206,86,1)',backgroundColor:'rgba(255,206,86,0.2)',tension:0.4,fill:true},{label:'Đúng giờ',data:days.map(d=>dailyData[d].ontime),borderColor:'rgba(75,192,192,1)',backgroundColor:'rgba(75,192,192,0.2)',tension:0.4,fill:true}]},options:{responsive:true,maintainAspectRatio:false,interaction:{mode:'index',intersect:false}}});}
const staffPerfCtx=document.getElementById('staffPerformanceChart');if(staffPerfCtx){const staffData=${JSON.stringify(staffStats.staffPerformance.slice(0,10))};new Chart(staffPerfCtx.getContext('2d'),{type:'bar',data:{labels:staffData.map(s=>s.name),datasets:[{label:'Tỷ lệ có ảnh (%)',data:staffData.map(s=>Math.round(s.imageRate*100)),backgroundColor:'rgba(255,206,86,0.8)',yAxisID:'y'},{label:'Tỷ lệ đúng giờ (%)',data:staffData.map(s=>Math.round(s.ontimeRate*100)),backgroundColor:'rgba(75,192,192,0.8)',yAxisID:'y'}]},options:{responsive:true,maintainAspectRatio:false,indexAxis:'y',scales:{x:{max:100,title:{display:true,text:'Tỷ lệ (%)'}},y:{beginAtZero:true}}}});}`;
}
generateHTML(dailyComparison, heatmap, hourlyUsage, robotData, robotEfficiency) {
const currentMonth = new Date().getMonth() + 1;
const previousMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const sortedDays = Object.keys(dailyComparison).sort((a, b) => b - a);
const recentDays = sortedDays.slice(0, 3);
const olderDays = sortedDays.slice(3);
return `<!DOCTYPE html><html lang="vi"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Báo cáo Robot - ${this.PROJECT_NAME} - ${this.formatDate(this.today, 'dd/mm/yyyy')}</title><script src="https://cdn.jsdelivr.net/npm/chart.js"></script><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;line-height:1.6;color:#333;background:#f5f5f5}.container{max-width:1400px;margin:0 auto;padding:20px}.header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;padding:30px;border-radius:10px;margin-bottom:30px;text-align:center}.tab-container{display:flex;gap:10px;margin-bottom:20px;background:white;padding:10px;border-radius:10px;box-shadow:0 2px 4px rgba(0,0,0,0.1)}.tab-button{padding:12px 24px;background:#f8f9fa;border:none;cursor:pointer;border-radius:5px;font-size:14px;font-weight:500;transition:all 0.3s}.tab-button:hover{background:#e9ecef}.tab-button.active{background:#667eea;color:white}.tab-content{display:none}.tab-content.active{display:block}.section{background:white;margin-bottom:30px;border-radius:10px;box-shadow:0 4px 6px rgba(0,0,0,0.1);overflow:hidden}.section-header{background:#f8f9fa;padding:20px;border-bottom:1px solid #dee2e6}.section-content{padding:30px}.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin-bottom:30px}.stat-card{background:linear-gradient(135deg,#74b9ff,#0984e3);color:white;padding:20px;border-radius:8px;text-align:center;position:relative}.stat-number{font-size:2.5em;font-weight:bold;margin-bottom:5px}.stat-label{font-size:0.9em;opacity:0.9}.stat-change{font-size:0.8em;margin-top:5px;opacity:0.9}.chart-container{background:white;padding:20px;border-radius:8px;margin:20px 0;height:400px}.table{width:100%;border-collapse:collapse;margin-top:20px}.table th,.table td{padding:12px;text-align:left;border-bottom:1px solid #dee2e6}.table th{background:#f8f9fa;font-weight:600}.table tr:hover{background:#f8f9fa}.heatmap{display:grid;grid-template-columns:repeat(25,1fr);gap:2px;margin:20px 0}.heatmap-cell{aspect-ratio:1;border-radius:2px;cursor:pointer;position:relative}.heatmap-cell:hover::after{content:attr(data-tooltip);position:absolute;bottom:100%;left:50%;transform:translateX(-50%);background:rgba(0,0,0,0.8);color:white;padding:5px 10px;border-radius:4px;white-space:nowrap;z-index:1000;font-size:12px}.heatmap-label{font-size:12px;font-weight:bold;display:flex;align-items:center;justify-content:center}.comparison-row{display:grid;grid-template-columns:100px 1fr 1fr;gap:10px;padding:10px;border-bottom:1px solid #eee}.comparison-row:hover{background:#f8f9fa}.positive{color:#00b894}.negative{color:#e17055}.neutral{color:#636e72}.btn-expand{background:#007bff;color:white;border:none;padding:8px 16px;border-radius:5px;cursor:pointer;margin:10px 0}.btn-expand:hover{background:#0056b3}.hidden{display:none}.insight{background:#fff3cd;border-left:4px solid #ffc107;padding:15px;margin:15px 0;border-radius:5px}.insight-title{font-weight:bold;margin-bottom:5px;color:#856404}.robot-efficiency-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:20px;margin:20px 0}.robot-card{background:#f8f9fa;padding:20px;border-radius:8px;border-left:4px solid #0984e3}.robot-card h4{margin-bottom:10px;color:#2d3436}.model-badge{display:inline-block;padding:4px 12px;border-radius:12px;font-size:12px;font-weight:bold;margin-left:10px}.model-75{background:#ff6b6b;color:white}.model-50{background:#ffa500;color:white}.model-40{background:#ffd93d;color:#333}.model-p{background:#6c5ce7;color:white}</style></head><body><div class="container"><div class="header"><h1>Báo cáo ${this.PROJECT_NAME}</h1><p>Tháng ${currentMonth} so với tháng ${previousMonth} | ${this.formatDate(this.today, 'dd/mm/yyyy')}</p></div><div class="tab-container"><button class="tab-button active" onclick="switchTab('daily')">Báo cáo hôm nay</button><button class="tab-button" onclick="switchTab('monthly')">Báo cáo tháng</button></div><div id="daily-tab" class="tab-content active"><div class="section"><div class="section-header"><h2>Bản đồ nhiệt theo giờ (Tháng ${currentMonth})</h2></div><div class="section-content"><div class="insight"><div class="insight-title">Chú thích màu sắc:</div>Vàng nhạt = Hoạt động dưới mức TB | Vàng = Gần mức TB | Cam = Trên mức TB | Đỏ = Cao hơn nhiều (>1.5x TB). Thời gian ước tính dựa trên tốc độ 1000m²/h.</div><div class="heatmap"><div class="heatmap-label"></div>${Array.from({length:24},(_, i) => `<div class="heatmap-label">${i}h</div>`).join('')}${Object.entries(heatmap.heatmap).map(([day, hours]) => {
const hasData = Object.values(hours).some(h => h.count > 0);
if (!hasData) return '';
return `<div class="heatmap-label">${day}</div>${Object.entries(hours).map(([hour, data]) => {
const color = this.generateHeatmapColor(data.count, heatmap.avgCount);
return `<div class="heatmap-cell" style="background:${color}" data-tooltip="Ngày ${day}, ${hour}h: ${data.count} robot, ${Math.round(data.totalArea)}m², ${Math.round(data.avgCompletion*100)}%"></div>`;
}).join('')}`;
}).join('')}</div></div></div><div class="section"><div class="section-header"><h2>Hiệu suất từng Robot (Tháng ${currentMonth})</h2></div><div class="section-content"><div class="insight"><div class="insight-title">Phân loại theo công suất:</div>Model 75 (GS100/GS400) = Cao nhất | Model 50 (GS101/GS401) = Trung bình cao | Model 40 (GS142) = Trung bình | Model P (GS438) = Chuyên dụng</div><div class="robot-efficiency-grid">${robotEfficiency.map(robot => {
const modelClass = robot.model.replace(/\s+/g, '-').toLowerCase();
return `<div class="robot-card"><h4>${robot.robotId}<span class="model-badge ${modelClass}">${robot.model}</span></h4><p><strong>Số lần sử dụng:</strong> ${robot.count}</p><p><strong>Tổng diện tích:</strong> ${Math.round(robot.totalArea).toLocaleString()} m²</p><p><strong>TB mỗi lần:</strong> ${Math.round(robot.avgAreaPerTask)} m²</p><p><strong>Hoàn thành TB:</strong> <span class="${robot.avgCompletion < 0.8 ? 'negative' : robot.avgCompletion >= 0.95 ? 'positive' : 'neutral'}">${Math.round(robot.avgCompletion * 100)}%</span></p><p><strong>Tốc độ TB:</strong> ${Math.round(robot.avgSpeed)} m²/h</p><p><strong>Hiệu suất pin:</strong> ${Math.round(robot.efficiency * 10) / 10} m²/%</p><p><strong>Tổng pin tiêu thụ:</strong> ${Math.round(robot.totalBattery)}%</p><p><strong>Tổng thời gian:</strong> ${Math.round(robot.totalDuration)} phút</p></div>`;
}).join('')}</div><div class="chart-container"><canvas id="robotEfficiencyChart"></canvas></div></div></div><div class="section"><div class="section-header"><h2>Chi tiết tất cả báo cáo (Tháng ${currentMonth})</h2></div><div class="section-content"><table class="table"><thead><tr><th>Ngày</th><th>Thời gian</th><th>Robot</th><th>Model</th><th>Khu vực</th><th>Đánh giá</th><th>Diện tích (m²)</th><th>Hoàn thành</th><th>Tốc độ</th><th>Pin</th></tr></thead><tbody>${robotData.filter(r => r.month === currentMonth).slice(0, 5).map(r => {
const completionClass = r.parsedData.completion < 0.8 ? 'negative' : r.parsedData.completion >= 0.95 ? 'positive' : 'neutral';
const modelClass = r.model.replace(/\s+/g, '-').toLowerCase();
return `<tr><td>${this.formatDate(new Date(r.Ngay), 'dd/mm/yyyy')}</td><td>${r.startTime} - ${r.Gio}</td><td>${r.robotId || 'N/A'}</td><td><span class="model-badge ${modelClass}">${r.model}</span></td><td>${r.area || 'N/A'}</td><td>${r.KetQua || '-'}</td><td>${Math.round(r.parsedData.actualArea)}</td><td class="${completionClass}">${Math.round(r.parsedData.completion * 100)}%</td><td>${Math.round(r.parsedData.speed)} m²/h</td><td>${r.parsedData.battery}%</td></tr>`;
}).join('')}</tbody></table>${robotData.filter(r => r.month === currentMonth).length > 5 ? `<button class="btn-expand" onclick="document.getElementById('allRobotReports').classList.toggle('hidden')">Xem thêm ${robotData.filter(r => r.month === currentMonth).length - 5} báo cáo</button><div id="allRobotReports" class="hidden"><table class="table"><tbody>${robotData.filter(r => r.month === currentMonth).slice(5).map(r => {
const completionClass = r.parsedData.completion < 0.8 ? 'negative' : r.parsedData.completion >= 0.95 ? 'positive' : 'neutral';
const modelClass = r.model.replace(/\s+/g, '-').toLowerCase();
return `<tr><td>${this.formatDate(new Date(r.Ngay), 'dd/mm/yyyy')}</td><td>${r.startTime} - ${r.Gio}</td><td>${r.robotId || 'N/A'}</td><td><span class="model-badge ${modelClass}">${r.model}</span></td><td>${r.area || 'N/A'}</td><td>${r.KetQua || '-'}</td><td>${Math.round(r.parsedData.actualArea)}</td><td class="${completionClass}">${Math.round(r.parsedData.completion * 100)}%</td><td>${Math.round(r.parsedData.speed)} m²/h</td><td>${r.parsedData.battery}%</td></tr>`;
}).join('')}</tbody></table></div>` : ''}</div></div></div><div id="monthly-tab" class="tab-content"></div></div><script>function switchTab(tab){document.querySelectorAll('.tab-button').forEach(btn=>btn.classList.remove('active'));document.querySelectorAll('.tab-content').forEach(content=>content.classList.remove('active'));event.target.classList.add('active');document.getElementById(tab+'-tab').classList.add('active');}const hourlyCtx=document.getElementById('hourlyChart');const robotEffCtx=document.getElementById('robotEfficiencyChart');if(robotEffCtx){new Chart(robotEffCtx.getContext('2d'),{type:'bar',data:{labels:${JSON.stringify(robotEfficiency.map(r => r.robotId))},datasets:[{label:'Tổng diện tích (m²)',data:${JSON.stringify(robotEfficiency.map(r => Math.round(r.totalArea)))},backgroundColor:${JSON.stringify(robotEfficiency.map(r => {
if (r.model === 'Model 75') return 'rgba(255,107,107,0.8)';
if (r.model === 'Model 50') return 'rgba(255,165,0,0.8)';
if (r.model === 'Model 40') return 'rgba(255,217,61,0.8)';
if (r.model === 'Model P') return 'rgba(108,92,231,0.8)';
return 'rgba(150,150,150,0.8)';
}))},yAxisID:'y'},{label:'Hoàn thành TB (%)',data:${JSON.stringify(robotEfficiency.map(r => Math.round(r.avgCompletion * 100)))},backgroundColor:'rgba(75,192,192,0.8)',type:'line',yAxisID:'y1',borderColor:'rgba(75,192,192,1)',tension:0.4}]},options:{responsive:true,maintainAspectRatio:false,indexAxis:'y',scales:{x:{title:{display:true,text:'Diện tích (m²)'}},y:{beginAtZero:true},y1:{type:'linear',position:'right',title:{display:true,text:'Hoàn thành (%)'},grid:{drawOnChartArea:false},max:100}}}});}</script></body></html>`;
}
async generate() {
try {
console.log('Bắt đầu tạo báo cáo T2...');
await this.connectDB();
const robotData = await this.getRobotData();
const machineryData = await this.getMachineryData();
const staffQualityData = await this.getStaffQualityData();
console.log(`Đã tải ${robotData.length} báo cáo robot, ${machineryData.length} báo cáo máy móc, ${staffQualityData.length} báo cáo nhân viên`);
const dailyComparison = this.generateDailyComparison(robotData);
const heatmap = this.generateHourlyHeatmap(robotData);
const hourlyUsage = this.generateHourlyUsage(robotData);
const robotEfficiency = this.generateRobotEfficiency(robotData);
const staffHeatmap = this.generateStaffQualityHeatmap(staffQualityData);
const positionConsistency = this.generatePositionConsistency(staffQualityData);
const resultConsistency = this.generateResultConsistency(staffQualityData);
const machineryHeatmap = this.generateMachineryHeatmap(machineryData);
const machineryHourlyUsage = this.generateMachineryHourlyUsage(machineryData);
const machineryEfficiency = this.generateMachineryEfficiency(machineryData);
const staffConsistency = this.generateStaffConsistency(machineryData);
const missingMachines = this.getMissingMachinesToday(machineryData);
const monthlyRobotStats = this.calculateMonthlyRobotStats(robotData);
const monthlyMachineryStats = this.calculateMonthlyMachineryStats(machineryData);
const monthlyStaffStats = this.calculateMonthlyStaffStats(staffQualityData);
const robotHTML = this.generateHTML(dailyComparison, heatmap, hourlyUsage, robotData, robotEfficiency);
const staffSection = this.generateStaffQualityHTMLSection(staffHeatmap, positionConsistency, resultConsistency, staffQualityData);
const machinerySection = this.generateMachineryHTMLSection(machineryHeatmap, machineryHourlyUsage, machineryEfficiency, staffConsistency, machineryData, missingMachines);
const monthlySection = this.generateMonthlySummaryHTML(monthlyRobotStats, monthlyMachineryStats, monthlyStaffStats);
const staffCharts = this.generateStaffQualityChartScripts(positionConsistency, resultConsistency);
const machineryCharts = this.generateMachineryChartScripts(machineryHourlyUsage, machineryEfficiency);
const monthlyCharts = this.generateMonthlyChartScripts(monthlyRobotStats, monthlyMachineryStats, monthlyStaffStats);
const html = robotHTML.replace('</script></body></html>', staffCharts + machineryCharts + '</script>' + staffSection + machinerySection + '</body></html>').replace('<div id="monthly-tab" class="tab-content"></div>', `<div id="monthly-tab" class="tab-content">${monthlySection}</div><script>${monthlyCharts}</script>`);
await fs.mkdir('./drive', { recursive: true });
await fs.writeFile(this.reportPath, html, 'utf8');
console.log(`Báo cáo đã được tạo: ${this.reportPath}`);
return { success: true, filePath: this.reportPath, totalRecords: robotData.length + machineryData.length + staffQualityData.length };
} catch (error) {
console.error('Lỗi:', error.message);
throw error;
} finally {
if (this.connection)await this.connection.end();
}
}
}
const T2_REPORT_RECIPIENTS = ['hongson@officity.vn','lienhuong@hoanmykleanco.com','kinhluuvan@hoanmykleanco.com','giangnguyen@hoanmykleanco.com','le.hang@hoanmykleanco.com','lequyen@hoanmykleanco.com','manhhung@officity.vn'];
async function main() {
const generator = new T2ReportGenerator();
const result = await generator.generate();
console.log('Hoàn thành!');
}
function scheduleReports() {
console.log('🚀 Khởi động hệ thống báo cáo T2...');
console.log('⏰ Sẽ chạy mỗi giờ vào phút thứ 5');
console.log('📧 Email tự động lúc 23:05 hàng ngày');
const checkAndRun = async () => {
const now = new Date();
const minute = now.getMinutes();
const hour = now.getHours();
if (minute === 5) {
console.log(`\n🔄 Bắt đầu tạo báo cáo - ${now.toLocaleString('vi-VN')}`);
try {
const generator = new T2ReportGenerator();
await generator.generate();
if (hour === 23) {
console.log('📧 Đang gửi email...');
await generator.sendT2Report();
}
console.log('✅ Hoàn thành!');
} catch (error) {
console.error('❌ Lỗi:', error.message);
}
await new Promise(resolve => setTimeout(resolve, 60000));
}
};
checkAndRun();
setInterval(checkAndRun, 60000);
console.log('✅ Hệ thống đã sẵn sàng. Nhấn Ctrl+C để dừng.\n');
}
if (require.main === module) {
const args = process.argv.slice(2);
if (args.includes('--now') || args.includes('-n')) {
main();
} else if (args.includes('--schedule-now')) {
(async () => {
console.log('🚀 Tạo báo cáo ngay lập tức...');
await main();
console.log('✅ Báo cáo đầu tiên hoàn thành. Bắt đầu chế độ tự động...\n');
scheduleReports();
})();
} else {
scheduleReports();
}
}
module.exports = { T2ReportGenerator };