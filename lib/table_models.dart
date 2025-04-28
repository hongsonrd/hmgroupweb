import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'multifile.dart';
class ChecklistInitializer {
  static const String tableKey = 'checklist_data';
  static const int batchSize = 500;
  static Future<void> initializeChecklistTable(Database db) async {
    try {
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.checklistTable}'));
      if (count == 0) {
        final Uint8List excelData = await MultiFileAccessUtility.getFileContent(tableKey);
        final excel = Excel.decodeBytes(excelData);
        final sheet = excel.tables[excel.tables.keys.first];
        if (sheet == null) throw Exception('No sheet found in Excel file');
        final headers = _getHeaders(sheet);
        List<Map<String, dynamic>> batch = [];
        for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
          final row = sheet.row(rowIndex);
          if (_isEmptyRow(row)) continue;
          final rowData = _processRow(headers, row);
          if (!rowData.containsKey('TASKID') || rowData['TASKID'] == null) {
            rowData['TASKID'] = const Uuid().v4();
          }
          batch.add(rowData);
          if (batch.length >= batchSize) {
            await _insertBatch(db, batch);
            batch = [];
          }
        }
        if (batch.isNotEmpty) {
          await _insertBatch(db, batch);
        }
      }
    } catch (e) {
      rethrow;
    }
  }
  static List<String> _getHeaders(Sheet sheet) {
    final headerRow = sheet.row(0);
    return headerRow.where((cell) => cell?.value != null).map((cell) => cell!.value.toString().trim().toUpperCase()).toList();
  }
  static bool _isEmptyRow(List<Data?> row) {
    return row.every((cell) => cell?.value == null);
  }
  static Map<String, dynamic> _processRow(List<String> headers, List<Data?> row) {
    final Map<String, dynamic> rowData = {};
    for (var i = 0; i < headers.length && i < row.length; i++) {
      final value = row[i]?.value;
      if (value != null) {
        if (value is double && headers[i] == 'NGAYBC') {
          final dateTime = DateTime(1899, 12, 30).add(Duration(days: value.toInt()));
          rowData[headers[i]] = dateTime.toIso8601String();
        } else {
          rowData[headers[i]] = value.toString();
        }
      }
    }
    return rowData;
  }
  static Future<void> _insertBatch(Database db, List<Map<String, dynamic>> batch) async {
    await db.transaction((txn) async {
      for (final row in batch) {
        await txn.insert(DatabaseTables.checklistTable, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
class ProjectListModel {
  final String boPhan;
  final String maBP;

  ProjectListModel({
    required this.boPhan,
    required this.maBP,
  });

  Map<String, dynamic> toMap() => {
    'BoPhan': boPhan,
    'MaBP': maBP,
  };

  factory ProjectListModel.fromMap(Map<String, dynamic> map) => ProjectListModel(
    boPhan: map['BoPhan'] ?? '',
    maBP: map['MaBP'] ?? '',
  );
}
class StaffbioModel {
  String? uid;
  String? vungMien;
  String? loaiNV;
  String? manv;
  String? hoTen;
  DateTime? ngayVao;
  DateTime? thangVao;
  int? soThang;
  String? loaiHinhLaoDong;
  String? chucVu;
  String? gioiTinh;
  DateTime? ngaySinh;
  int? tuoi;
  String? canCuocCongDan;
  DateTime? ngayCap;
  String? noiCap;
  String? nguyenQuan;
  String? thuongTru;
  String? diaChiLienLac;
  String? maSoThue;
  String? cMNDCu;
  String? ngay_cap_cu;
  String? noiCapCu;
  String? nguyenQuanCu;
  String? diaChiThuongTruCu;
  String? mstGhiChu;
  String? danToc;
  String? sdt;
  String? sdt2;
  String? email;
  String? diaChinhCap4;
  String? diaChinhCap3;
  String? diaChinhCap2;
  String? diaChinhCap1;
  String? donVi;
  String? giamSat;
  String? soTaiKhoan;
  String? nganHang;
  String? mstThuNhapCaNhan;
  String? soBHXH;
  String? batDauThamGiaBHXH;
  String? ketThucBHXH;
  String? ghiChu;
  String? tinhTrang;
  DateTime? ngayNghi;
  String? tinhTrangHoSo;
  String? hoSoConThieu;
  String? quaTrinh;
  String? partime;
  String? nguoiGioiThieu;
  String? nguonTuyenDung;
  String? ctv30k;
  String? doanhSoTuyenDung;
  String? trinhDo;
  String? chuyenNganh;
  String? plDacBiet;
  String? lam2noi;
  String? loaiDt;
  String? soTheBHHuuTri;
  String? tinhTrangTiemChung;
  DateTime? ngayCapGiayKhamSK;
  String? sdtNhanThan;
  String? hoTenBo;
  String? namSinhBo;
  String? hoTenMe;
  String? namSinhMe;
  String? hoTenVoChong;
  String? namSinhVoChong;
  String? con;
  String? namSinhCon;
  String? chuHoKhau;
  String? namSinhChuHo;
  String? quanHeVoiChuHo;
  String? hoSoThau;
  String? soTheBHYT;
  double? chieuCao;
  double? canNang;
  DateTime? ngayCapDP;

  StaffbioModel({
    this.uid,
    this.vungMien,
    this.loaiNV,
    this.manv,
    this.hoTen,
    this.ngayVao,
    this.thangVao,
    this.soThang,
    this.loaiHinhLaoDong,
    this.chucVu,
    this.gioiTinh,
    this.ngaySinh,
    this.tuoi,
    this.canCuocCongDan,
    this.ngayCap,
    this.noiCap,
    this.nguyenQuan,
    this.thuongTru,
    this.diaChiLienLac,
    this.maSoThue,
    this.cMNDCu,
    this.ngay_cap_cu,
    this.noiCapCu,
    this.nguyenQuanCu,
    this.diaChiThuongTruCu,
    this.mstGhiChu,
    this.danToc,
    this.sdt,
    this.sdt2,
    this.email,
    this.diaChinhCap4,
    this.diaChinhCap3,
    this.diaChinhCap2,
    this.diaChinhCap1,
    this.donVi,
    this.giamSat,
    this.soTaiKhoan,
    this.nganHang,
    this.mstThuNhapCaNhan,
    this.soBHXH,
    this.batDauThamGiaBHXH,
    this.ketThucBHXH,
    this.ghiChu,
    this.tinhTrang,
    this.ngayNghi,
    this.tinhTrangHoSo,
    this.hoSoConThieu,
    this.quaTrinh,
    this.partime,
    this.nguoiGioiThieu,
    this.nguonTuyenDung,
    this.ctv30k,
    this.doanhSoTuyenDung,
    this.trinhDo,
    this.chuyenNganh,
    this.plDacBiet,
    this.lam2noi,
    this.loaiDt,
    this.soTheBHHuuTri,
    this.tinhTrangTiemChung,
    this.ngayCapGiayKhamSK,
    this.sdtNhanThan,
    this.hoTenBo,
    this.namSinhBo,
    this.hoTenMe,
    this.namSinhMe,
    this.hoTenVoChong,
    this.namSinhVoChong,
    this.con,
    this.namSinhCon,
    this.chuHoKhau,
    this.namSinhChuHo,
    this.quanHeVoiChuHo,
    this.hoSoThau,
    this.soTheBHYT,
    this.chieuCao,
    this.canNang,
    this.ngayCapDP,
  });
 Map<String, dynamic> toMap() {
    return {
      'UID': uid ?? '',
      'VungMien': vungMien ?? '',
      'LoaiNV': loaiNV ?? '',
      'MaNV': manv ?? '',
      'Ho_ten': hoTen ?? '',
      'Ngay_vao': ngayVao?.toIso8601String(),
      'Thang_vao': thangVao?.toIso8601String(),
      'So_thang': soThang,
      'Loai_hinh_lao_dong': loaiHinhLaoDong ?? '',
      'Chuc_vu': chucVu ?? '',
      'Gioi_tinh': gioiTinh ?? '',
      'Ngay_sinh': ngaySinh?.toIso8601String(),
      'Tuoi': tuoi,
      'Can_cuoc_cong_dan': canCuocCongDan ?? '',
      'Ngay_cap': ngayCap?.toIso8601String(),
      'Noi_cap': noiCap ?? '',
      'Nguyen_quan': nguyenQuan ?? '',
      'Thuong_tru': thuongTru ?? '',
      'Dia_chi_lien_lac': diaChiLienLac ?? '',
      'Ma_so_thue': maSoThue ?? '',
      'CMND_cu': cMNDCu ?? '',
      'ngay_cap_cu': ngay_cap_cu ?? '',
      'Noi_cap_cu': noiCapCu ?? '',
      'Nguyen_quan_cu': nguyenQuanCu ?? '',
      'Dia_chi_thuong_tru_cu': diaChiThuongTruCu ?? '',
      'MST_ghi_chu': mstGhiChu ?? '',
      'Dan_toc': danToc ?? '',
      'SDT': sdt ?? '',
      'SDT2': sdt2 ?? '',
      'Email': email ?? '',
      'Dia_chinh_cap4': diaChinhCap4 ?? '',
      'Dia_chinh_cap3': diaChinhCap3 ?? '',
      'Dia_chinh_cap2': diaChinhCap2 ?? '',
      'Dia_chinh_cap1': diaChinhCap1 ?? '',
      'Don_vi': donVi ?? '',
      'Giam_sat': giamSat ?? '',
      'So_tai_khoan': soTaiKhoan ?? '',
      'Ngan_hang': nganHang ?? '',
      'MST_thu_nhap_ca_nhan': mstThuNhapCaNhan ?? '',
      'So_BHXH': soBHXH ?? '',
      'Bat_dau_tham_gia_BHXH': batDauThamGiaBHXH ?? '',
      'Ket_thuc_BHXH': ketThucBHXH ?? '',
      'Ghi_chu': ghiChu ?? '',
      'Tinh_trang': tinhTrang ?? '',
      'Ngay_nghi': ngayNghi?.toIso8601String(),
      'Tinh_trang_ho_so': tinhTrangHoSo ?? '',
      'Ho_so_con_thieu': hoSoConThieu ?? '',
      'Qua_trinh': quaTrinh ?? '',
      'Partime': partime ?? '',
      'Nguoi_gioi_thieu': nguoiGioiThieu ?? '',
      'Nguon_tuyen_dung': nguonTuyenDung ?? '',
      'CTV_30k': ctv30k ?? '',
      'Doanh_so_tuyen_dung': doanhSoTuyenDung ?? '',
      'Trinh_do': trinhDo ?? '',
      'Chuyen_nganh': chuyenNganh ?? '',
      'PL_dac_biet': plDacBiet ?? '',
      'Lam_2noi': lam2noi ?? '',
      'Loai_dt': loaiDt ?? '',
      'So_the_BH_huu_tri': soTheBHHuuTri ?? '',
      'Tinh_trang_tiem_chung': tinhTrangTiemChung ?? '',
      'Ngay_cap_giay_khamSK': ngayCapGiayKhamSK?.toIso8601String(),
      'SDT_nhan_than': sdtNhanThan ?? '',
      'Ho_ten_bo': hoTenBo ?? '',
      'Nam_sinh_bo': namSinhBo ?? '',
      'Ho_ten_me': hoTenMe ?? '',
      'Nam_sinh_me': namSinhMe ?? '',
      'Ho_ten_vochong': hoTenVoChong ?? '',
      'Nam_sinh_vochong': namSinhVoChong ?? '',
      'Con': con ?? '',
      'Nam_sinh_con': namSinhCon ?? '',
      'Chu_ho_khau': chuHoKhau ?? '',
      'Nam_sinh_chu_ho': namSinhChuHo ?? '',
      'Quan_he_voi_chu_ho': quanHeVoiChuHo ?? '',
      'Ho_so_thau': hoSoThau ?? '',
      'So_the_BHYT': soTheBHYT ?? '',
      'ChieuCao': chieuCao,
      'CanNang': canNang,
      'NgayCapDP': ngayCapDP?.toIso8601String(),
    };
  }
  static StaffbioModel fromMap(Map<String, dynamic> map) {
    return StaffbioModel(
      uid: map['UID']?.toString(),
      vungMien: map['VungMien']?.toString(),
      loaiNV: map['LoaiNV']?.toString(),
      manv: map['MaNV']?.toString(),
      hoTen: map['Ho_ten']?.toString(),
      ngayVao: map['Ngay_vao'] != null && map['Ngay_vao'].toString().isNotEmpty 
          ? DateTime.tryParse(map['Ngay_vao']) 
          : null,
      thangVao: map['Thang_vao'] != null && map['Thang_vao'].toString().isNotEmpty 
          ? DateTime.tryParse(map['Thang_vao']) 
          : null,
      soThang: _toInt(map['So_thang']),
      loaiHinhLaoDong: map['Loai_hinh_lao_dong']?.toString(),
      chucVu: map['Chuc_vu']?.toString(),
      gioiTinh: map['Gioi_tinh']?.toString(),
      ngaySinh: map['Ngay_sinh'] != null && map['Ngay_sinh'].toString().isNotEmpty 
          ? DateTime.tryParse(map['Ngay_sinh']) 
          : null,
      tuoi: _toInt(map['Tuoi']),
      canCuocCongDan: map['Can_cuoc_cong_dan']?.toString() ?? '',
      ngayCap: map['Ngay_cap'] != null && map['Ngay_cap'].toString().isNotEmpty 
          ? DateTime.tryParse(map['Ngay_cap']) 
          : null,
      noiCap: map['Noi_cap']?.toString() ?? '',
      nguyenQuan: map['Nguyen_quan']?.toString() ?? '',
      thuongTru: map['Thuong_tru']?.toString() ?? '',
      diaChiLienLac: map['Dia_chi_lien_lac']?.toString() ?? '',
      maSoThue: map['Ma_so_thue']?.toString() ?? '',
      cMNDCu: map['CMND_cu']?.toString() ?? '',
      ngay_cap_cu: map['ngay_cap_cu']?.toString() ?? '',
      noiCapCu: map['Noi_cap_cu']?.toString() ?? '',
      nguyenQuanCu: map['Nguyen_quan_cu']?.toString() ?? '',
      diaChiThuongTruCu: map['Dia_chi_thuong_tru_cu']?.toString() ?? '',
      mstGhiChu: map['MST_ghi_chu']?.toString() ?? '',
      danToc: map['Dan_toc']?.toString() ?? '',
      sdt: map['SDT']?.toString() ?? '',
      sdt2: map['SDT2']?.toString() ?? '',
      email: map['Email']?.toString() ?? '',
      diaChinhCap4: map['Dia_chinh_cap4']?.toString() ?? '',
      diaChinhCap3: map['Dia_chinh_cap3']?.toString() ?? '',
      diaChinhCap2: map['Dia_chinh_cap2']?.toString() ?? '',
      diaChinhCap1: map['Dia_chinh_cap1']?.toString() ?? '',
      donVi: map['Don_vi']?.toString() ?? '',
      giamSat: map['Giam_sat']?.toString() ?? '',
      soTaiKhoan: map['So_tai_khoan']?.toString() ?? '',
      nganHang: map['Ngan_hang']?.toString() ?? '',
      mstThuNhapCaNhan: map['MST_thu_nhap_ca_nhan']?.toString() ?? '',
      soBHXH: map['So_BHXH']?.toString() ?? '',
      batDauThamGiaBHXH: map['Bat_dau_tham_gia_BHXH']?.toString() ?? '',
      ketThucBHXH: map['Ket_thuc_BHXH']?.toString() ?? '',
      ghiChu: map['Ghi_chu']?.toString() ?? '',
      tinhTrang: map['Tinh_trang']?.toString() ?? '',
      ngayNghi: map['Ngay_nghi'] != null && map['Ngay_nghi'].toString().isNotEmpty 
          ? DateTime.tryParse(map['Ngay_nghi']) 
          : null,
      tinhTrangHoSo: map['Tinh_trang_ho_so']?.toString() ?? '',
      hoSoConThieu: map['Ho_so_con_thieu']?.toString() ?? '',
      quaTrinh: map['Qua_trinh']?.toString() ?? '',
      partime: map['Partime']?.toString() ?? '',
      nguoiGioiThieu: map['Nguoi_gioi_thieu']?.toString() ?? '',
      nguonTuyenDung: map['Nguon_tuyen_dung']?.toString() ?? '',
      ctv30k: map['CTV_30k']?.toString() ?? '',
      doanhSoTuyenDung: map['Doanh_so_tuyen_dung']?.toString() ?? '',
      trinhDo: map['Trinh_do']?.toString() ?? '',
      chuyenNganh: map['Chuyen_nganh']?.toString() ?? '',
      plDacBiet: map['PL_dac_biet']?.toString() ?? '',
      lam2noi: map['Lam_2noi']?.toString() ?? '',
      loaiDt: map['Loai_dt']?.toString() ?? '',
      soTheBHHuuTri: map['So_the_BH_huu_tri']?.toString() ?? '',
      tinhTrangTiemChung: map['Tinh_trang_tiem_chung']?.toString() ?? '',
      ngayCapGiayKhamSK: map['Ngay_cap_giay_khamSK'] != null && map['Ngay_cap_giay_khamSK'].toString().isNotEmpty 
          ? DateTime.tryParse(map['Ngay_cap_giay_khamSK']) 
          : null,
      sdtNhanThan: map['SDT_nhan_than']?.toString() ?? '',
      hoTenBo: map['Ho_ten_bo']?.toString() ?? '',
      namSinhBo: map['Nam_sinh_bo']?.toString() ?? '',
      hoTenMe: map['Ho_ten_me']?.toString() ?? '',
      namSinhMe: map['Nam_sinh_me']?.toString() ?? '',
      hoTenVoChong: map['Ho_ten_vochong']?.toString() ?? '',
      namSinhVoChong: map['Nam_sinh_vochong']?.toString() ?? '',
      con: map['Con']?.toString() ?? '',
      namSinhCon: map['Nam_sinh_con']?.toString() ?? '',
      chuHoKhau: map['Chu_ho_khau']?.toString() ?? '',
      namSinhChuHo: map['Nam_sinh_chu_ho']?.toString() ?? '',
      quanHeVoiChuHo: map['Quan_he_voi_chu_ho']?.toString() ?? '',
      hoSoThau: map['Ho_so_thau']?.toString() ?? '',
      soTheBHYT: map['So_the_BHYT']?.toString() ?? '',
      // Improved numeric parsing for ChieuCao and CanNang
      chieuCao: _toDoubleNullable(map['ChieuCao']),
      canNang: _toDoubleNullable(map['CanNang']),
      ngayCapDP: map['NgayCapDP'] != null && map['NgayCapDP'].toString().isNotEmpty 
          ? DateTime.tryParse(map['NgayCapDP']) 
          : null,
    );
  }

  // Add a new method to safely convert to double
  static double? _toDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Try parsing the string as a double
      return double.tryParse(value);
    }
    return null;
  }

  // Keep the existing _toInt method
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class ChecklistModel {
  String? duan, vitri, weekday, start, end, task, tuan, thang;
  DateTime? ngaybc;
  final String taskid;
  ChecklistModel({required this.taskid, this.duan, this.vitri, this.weekday, this.start, this.end, this.task, this.tuan, this.thang, this.ngaybc});
  Map<String, dynamic> toMap() => {
    'TASKID': taskid,
    'DUAN': duan,
    'VITRI': vitri,
    'WEEKDAY': weekday,
    'START': start,
    'END': end,
    'TASK': task,
    'TUAN': tuan,
    'THANG': thang,
    'NGAYBC': ngaybc?.toIso8601String()
  };
  factory ChecklistModel.fromMap(Map<String, dynamic> map) => ChecklistModel(
    taskid: map['TASKID'],
    duan: map['DUAN'],
    vitri: map['VITRI'],
    weekday: map['WEEKDAY'],
    start: map['START'],
    end: map['END'],
    task: map['TASK'],
    tuan: map['TUAN'],
    thang: map['THANG'],
    ngaybc: map['NGAYBC'] != null ? DateTime.parse(map['NGAYBC']) : null
  );
}
class TaskHistoryModel {
  final String uid;
  final String taskId;
  final DateTime ngay;
  final String gio;
  String? nguoiDung, ketQua, chiTiet, chiTiet2, viTri, boPhan, phanLoai, hinhAnh, giaiPhap;
  TaskHistoryModel({required this.uid, required this.taskId, required this.ngay, required this.gio, this.nguoiDung, this.ketQua, this.chiTiet,this.chiTiet2, this.viTri, this.boPhan, this.phanLoai, this.hinhAnh, this.giaiPhap});
  Map<String, dynamic> toMap() => {
    'UID': uid,
    'TaskID': taskId,
    'Ngay': ngay.toIso8601String(),
    'Gio': gio,
    'NguoiDung': nguoiDung,
    'KetQua': ketQua,
    'ChiTiet': chiTiet,
    'ChiTiet2': chiTiet2,
    'ViTri': viTri,
    'BoPhan': boPhan,
    'PhanLoai': phanLoai,
    'HinhAnh': hinhAnh,
    'GiaiPhap': giaiPhap,
  };
  factory TaskHistoryModel.fromMap(Map<String, dynamic> map) => TaskHistoryModel(
    uid: map['UID'],
    taskId: map['TaskID'],
    ngay: DateTime.parse(map['Ngay']),
    gio: map['Gio'],
    nguoiDung: map['NguoiDung'],
    ketQua: map['KetQua'],
    chiTiet: map['ChiTiet'],
    chiTiet2: map['ChiTiet2'],
    viTri: map['ViTri'],
    boPhan: map['BoPhan'],
    phanLoai: map['PhanLoai'],
    hinhAnh: map['HinhAnh'],
    giaiPhap: map['GiaiPhap']
  );
}
class VTHistoryModel {
  final String uid;
  final DateTime ngay;
  final String gio;
  String? nguoiDung, boPhan, viTri, nhanVien, trangThai, hoTro, phuongAn;
  VTHistoryModel({required this.uid, required this.ngay, required this.gio, this.nguoiDung, this.boPhan, this.viTri, this.nhanVien, this.trangThai, this.hoTro, this.phuongAn});
  Map<String, dynamic> toMap() => {
    'UID': uid,
    'Ngay': ngay.toIso8601String(),
    'Gio': gio,
    'NguoiDung': nguoiDung,
    'BoPhan': boPhan,
    'ViTri': viTri,
    'NhanVien': nhanVien,
    'TrangThai': trangThai,
    'HoTro': hoTro,
    'PhuongAn': phuongAn
  };
  factory VTHistoryModel.fromMap(Map<String, dynamic> map) => VTHistoryModel(
    uid: map['UID'],
    ngay: DateTime.parse(map['Ngay']),
    gio: map['Gio'],
    nguoiDung: map['NguoiDung'],
    boPhan: map['BoPhan'],
    viTri: map['ViTri'],
    nhanVien: map['NhanVien'],
    trangThai: map['TrangThai'],
    hoTro: map['HoTro'],
    phuongAn: map['PhuongAn']
  );
}
class BaocaoModel {
  final String uid;
  final DateTime ngay;
  final String gio;
  String? nguoiDung, boPhan, chiaSe, phanLoai, hinhAnh;
  String? moTaChung, giaiPhapChung;
  String? danhGiaNS, giaiPhapNS;
  String? danhGiaCL, giaiPhapCL;
  String? danhGiaVT, giaiPhapVT;
  String? danhGiaYKienKhachHang, giaiPhapYKienKhachHang;
  String? danhGiaMayMoc, giaiPhapMayMoc;
  String? nhom, phatSinh, xetDuyet;

  BaocaoModel({
    required this.uid,
    required this.ngay,
    required this.gio,
    this.nguoiDung,
    this.boPhan,
    this.chiaSe,
    this.phanLoai,
    this.hinhAnh,
    this.moTaChung,
    this.giaiPhapChung,
    this.danhGiaNS,
    this.giaiPhapNS,
    this.danhGiaCL,
    this.giaiPhapCL,
    this.danhGiaVT,
    this.giaiPhapVT,
    this.danhGiaYKienKhachHang,
    this.giaiPhapYKienKhachHang,
    this.danhGiaMayMoc,
    this.giaiPhapMayMoc,
    this.nhom,
    this.phatSinh,
    this.xetDuyet,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'Ngay': ngay.toIso8601String(),
    'Gio': gio,
    'NguoiDung': nguoiDung,
    'BoPhan': boPhan,
    'ChiaSe': chiaSe,
    'PhanLoai': phanLoai,
    'HinhAnh': hinhAnh,
    'MoTaChung': moTaChung,
    'GiaiPhapChung': giaiPhapChung,
    'DanhGiaNS': danhGiaNS,
    'GiaiPhapNS': giaiPhapNS,
    'DanhGiaCL': danhGiaCL,
    'GiaiPhapCL': giaiPhapCL,
    'DanhGiaVT': danhGiaVT,
    'GiaiPhapVT': giaiPhapVT,
    'DanhGiaYKienKhachHang': danhGiaYKienKhachHang,
    'GiaiPhapYKienKhachHang': giaiPhapYKienKhachHang,
    'DanhGiaMayMoc': danhGiaMayMoc,
    'GiaiPhapMayMoc': giaiPhapMayMoc,
    'Nhom': nhom,
    'PhatSinh': phatSinh,
    'XetDuyet': xetDuyet,
  };

  factory BaocaoModel.fromMap(Map<String, dynamic> map) {
  // Safely parse DateTime, defaulting to current date if parsing fails
  DateTime parseDate(dynamic dateValue) {
    try {
      return dateValue != null ? DateTime.parse(dateValue.toString()) : DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  // Safely convert to string, defaulting to empty string if null
  String? parseString(dynamic value) {
    return value?.toString() ?? '';
  }

  return BaocaoModel(
    uid: parseString(map['UID']) ?? '',  // Ensure non-null uid
    ngay: parseDate(map['Ngay']),
    gio: parseString(map['Gio']) ?? '00:00',  // Default time if null
    nguoiDung: parseString(map['NguoiDung']),
    boPhan: parseString(map['BoPhan']),
    chiaSe: parseString(map['ChiaSe']),
    phanLoai: parseString(map['PhanLoai']),
    hinhAnh: parseString(map['HinhAnh']),
    moTaChung: parseString(map['MoTaChung']),
    giaiPhapChung: parseString(map['GiaiPhapChung']),
    danhGiaNS: parseString(map['DanhGiaNS']),
    giaiPhapNS: parseString(map['GiaiPhapNS']),
    danhGiaCL: parseString(map['DanhGiaCL']),
    giaiPhapCL: parseString(map['GiaiPhapCL']),
    danhGiaVT: parseString(map['DanhGiaVT']),
    giaiPhapVT: parseString(map['GiaiPhapVT']),
    danhGiaYKienKhachHang: parseString(map['DanhGiaYKienKhachHang']),
    giaiPhapYKienKhachHang: parseString(map['GiaiPhapYKienKhachHang']),
    danhGiaMayMoc: parseString(map['DanhGiaMayMoc']),
    giaiPhapMayMoc: parseString(map['GiaiPhapMayMoc']),
    nhom: parseString(map['Nhom']),
    phatSinh: parseString(map['PhatSinh']),
    xetDuyet: parseString(map['XetDuyet']),
  );
}
}
// DongPhuc Model
class DongPhucModel {
  final String uid;
  final String nguoiDung;
  final String boPhan;
  final String phanLoai;
  DateTime? thoiGianNhan;
  String? trangThai;
  DateTime? thang;
  String? xuLy;

  DongPhucModel({
    required this.uid,
    required this.nguoiDung,
    required this.boPhan,
    required this.phanLoai,
    this.thoiGianNhan,
    this.trangThai,
    this.thang,
    this.xuLy,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'NguoiDung': nguoiDung,
    'BoPhan': boPhan,
    'PhanLoai': phanLoai,
    'ThoiGianNhan': thoiGianNhan?.toIso8601String(),
    'TrangThai': trangThai,
    'Thang': thang?.toIso8601String(),
    'XuLy': xuLy,
  };

  factory DongPhucModel.fromMap(Map<String, dynamic> map) => DongPhucModel(
    uid: map['UID'],
    nguoiDung: map['NguoiDung'],
    boPhan: map['BoPhan'],
    phanLoai: map['PhanLoai'],
    thoiGianNhan: map['ThoiGianNhan'] != null ? DateTime.parse(map['ThoiGianNhan']) : null,
    trangThai: map['TrangThai'],
    thang: map['Thang'] != null ? DateTime.parse(map['Thang']) : null,
    xuLy: map['XuLy'],
  );
}

// ChiTietDP Model
class ChiTietDPModel {
  final String orderUid;
  final String uid;
  DateTime? thoiGianGanNhat;
  String? maCN;
  String? ten;
  String? gioiTinh;
  String? loaiAo;
  String? sizeAo;
  String? loaiQuan;
  String? sizeQuan;
  String? loaiGiay;
  String? sizeGiay;
  String? loaiKhac;
  String? sizeKhac;
  String? ghiChu;

  ChiTietDPModel({
    required this.orderUid,
    required this.uid,
    this.thoiGianGanNhat,
    this.maCN,
    this.ten,
    this.gioiTinh,
    this.loaiAo,
    this.sizeAo,
    this.loaiQuan,
    this.sizeQuan,
    this.loaiGiay,
    this.sizeGiay,
    this.loaiKhac,
    this.sizeKhac,
    this.ghiChu,
  });

  Map<String, dynamic> toMap() {
  final map = {
    'UID': uid,
    'OrderUID': orderUid,
    'MaCN': maCN,
    'Ten': ten,
    'GioiTinh': gioiTinh,
    'ThoiGianGanNhat': thoiGianGanNhat?.toIso8601String(),
    'LoaiAo': loaiAo,
    'SizeAo': sizeAo,
    'LoaiQuan': loaiQuan,
    'SizeQuan': sizeQuan,
    'LoaiGiay': loaiGiay,
    'SizeGiay': sizeGiay,
    'LoaiKhac': loaiKhac,
    'SizeKhac': sizeKhac,
    'GhiChu': ghiChu,
  };
  print('Converting to map: $map');
  return map;
}

  factory ChiTietDPModel.fromMap(Map<String, dynamic> map) => ChiTietDPModel(
    orderUid: map['OrderUID'],
    uid: map['UID'],
    thoiGianGanNhat: map['ThoiGianGanNhat'] != null ? DateTime.parse(map['ThoiGianGanNhat']) : null,
    maCN: map['MaCN'],
    ten: map['Ten'],
    gioiTinh: map['GioiTinh'],
    loaiAo: map['LoaiAo'],
    sizeAo: map['SizeAo'],
    loaiQuan: map['LoaiQuan'],
    sizeQuan: map['SizeQuan'],
    loaiGiay: map['LoaiGiay'],
    sizeGiay: map['SizeGiay'],
    loaiKhac: map['LoaiKhac'],
    sizeKhac: map['SizeKhac'],
    ghiChu: map['GiChu'],
  );
}
class InteractionModel {
  final String uid;
  final DateTime ngay;
  final String gio;
  String? nguoiDung;
  String? boPhan;
  String? giamSat;
  String? noiDung;
  String? chuDe;
  String? phanLoai;

  InteractionModel({
    required this.uid,
    required this.ngay,
    required this.gio,
    this.nguoiDung,
    this.boPhan,
    this.giamSat,
    this.noiDung,
    this.chuDe,
    this.phanLoai,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'Ngay': ngay.toIso8601String(),
    'Gio': gio,
    'NguoiDung': nguoiDung,
    'BoPhan': boPhan,
    'GiamSat': giamSat,
    'NoiDung': noiDung,
    'ChuDe': chuDe,
    'PhanLoai': phanLoai,
  };

  factory InteractionModel.fromMap(Map<String, dynamic> map) => InteractionModel(
    uid: map['UID'],
    ngay: DateTime.parse(map['Ngay']),
    gio: map['Gio'],
    nguoiDung: map['NguoiDung'],
    boPhan: map['BoPhan'],
    giamSat: map['GiamSat'],
    noiDung: map['NoiDung'],
    chuDe: map['ChuDe'],
    phanLoai: map['PhanLoai'],
  );
}
class StaffListModel {
  final String uid;
  String? manv, nguoiDung, vt, boPhan;
  StaffListModel({required this.uid, this.manv, this.nguoiDung, this.vt, this.boPhan});
  Map<String, dynamic> toMap() => {
    'UID': uid,
    'MaNV': manv,
    'NguoiDung': nguoiDung,
    'VT': vt,
    'BoPhan': boPhan
  };
  factory StaffListModel.fromMap(Map<String, dynamic> map) => StaffListModel(
    uid: map['UID'],
    manv: map['MaNV'],
    nguoiDung: map['NguoiDung'],
    vt: map['VT'],
    boPhan: map['BoPhan']
  );
}
class PositionListModel {
  final String uid;
  String? boPhan, nguoiDung, vt, khuVuc, caBatdau, caKetthuc;
  PositionListModel({required this.uid, this.boPhan, this.nguoiDung, this.vt, this.khuVuc, this.caBatdau, this.caKetthuc});
  Map<String, dynamic> toMap() => {
    'UID': uid,
    'BoPhan': boPhan,
    'NguoiDung': nguoiDung,
    'VT': vt,
    'KhuVuc': khuVuc,
    'Ca_batdau': caBatdau,
    'Ca_ketthuc': caKetthuc
  };
  factory PositionListModel.fromMap(Map<String, dynamic> map) => PositionListModel(
    uid: map['UID'],
    boPhan: map['BoPhan'],
    nguoiDung: map['NguoiDung'],
    vt: map['VT'],
    khuVuc: map['KhuVuc'],
    caBatdau: map['Ca_batdau'],
    caKetthuc: map['Ca_ketthuc']
  );
}
// 1. Order Model
class OrderModel {
  final String orderId;
  DateTime? ngay;
  String? tenDon;
  String? boPhan;
  String? nguoiDung;
  String? trangThai;
  String? ghiChu;
  int? dinhMuc;
  String? nguoiDuyet;
  int? tongTien;
  String? phanLoai;
  DateTime? ngayCapNhat;
  String? vanDe;
  String? hinhAnh;

  OrderModel({
    required this.orderId,
    this.ngay,
    this.tenDon,
    this.boPhan,
    this.nguoiDung,
    this.trangThai,
    this.ghiChu,
    this.dinhMuc,
    this.nguoiDuyet,
    this.tongTien,
    this.phanLoai,
    this.ngayCapNhat,
    this.vanDe,
    this.hinhAnh,
  });

  Map<String, dynamic> toMap() => {
    'OrderID': orderId,
    'Ngay': ngay?.toIso8601String(),
    'TenDon': tenDon,
    'BoPhan': boPhan,
    'NguoiDung': nguoiDung,
    'TrangThai': trangThai,
    'GhiChu': ghiChu,
    'DinhMuc': dinhMuc,
    'NguoiDuyet': nguoiDuyet,
    'TongTien': tongTien,
    'PhanLoai': phanLoai,
    'NgayCapNhat': ngayCapNhat?.toIso8601String(),
    'VanDe': vanDe,
    'HinhAnh': hinhAnh,
  };

  factory OrderModel.fromMap(Map<String, dynamic> map) { 
    int? parseInteger(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }
    return OrderModel(
    orderId: map['OrderID'],
    ngay: map['Ngay'] != null ? DateTime.parse(map['Ngay']) : null,
    tenDon: map['TenDon'],
    boPhan: map['BoPhan'],
    nguoiDung: map['NguoiDung'],
    trangThai: map['TrangThai'],
    ghiChu: map['GhiChu'],
    dinhMuc: parseInteger(map['DinhMuc']),
    nguoiDuyet: map['NguoiDuyet'],
    tongTien: parseInteger(map['TongTien']),
    phanLoai: map['PhanLoai'],
    ngayCapNhat: map['NgayCapNhat'] != null ? DateTime.parse(map['NgayCapNhat']) : null,
    vanDe: map['VanDe'],
    hinhAnh: map['HinhAnh'],
  );
}}

// 2. OrderDinhMuc Model
class OrderDinhMucModel {
  final String boPhan;
  final String thangDat;
  String? nguoiDuyet;
  String? nguoiDung;
  String? maKho;
  int? tanSuat;
  String? ghiChu;
  double? soCongNhan;
  int? dinhMucTCN;
  int? congTruKhac;
  int? dinhMuc;

  OrderDinhMucModel({
    required this.boPhan,
    required this.thangDat,
    this.nguoiDuyet,
    this.nguoiDung,
    this.maKho,
    this.tanSuat,
    this.ghiChu,
    this.soCongNhan,
    this.dinhMucTCN,
    this.congTruKhac,
    this.dinhMuc,
  });

  Map<String, dynamic> toMap() => {
    'BoPhan': boPhan,
    'ThangDat': thangDat,
    'NguoiDuyet': nguoiDuyet,
    'NguoiDung': nguoiDung,
    'MaKho': maKho,
    'TanSuat': tanSuat,
    'GhiChu': ghiChu,
    'SoCongNhan': soCongNhan,
    'DinhMucTCN': dinhMucTCN,
    'CongTruKhac': congTruKhac,
    'DinhMuc': dinhMuc,
  };

  factory OrderDinhMucModel.fromMap(Map<String, dynamic> map) {
    int? parseInteger(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return OrderDinhMucModel(
      boPhan: map['BoPhan'] ?? '',
      thangDat: map['ThangDat'] ?? '',
      nguoiDuyet: map['NguoiDuyet']?.toString(),
      nguoiDung: map['NguoiDung']?.toString(),
      maKho: map['MaKho']?.toString(),
      tanSuat: parseInteger(map['TanSuat']),
      ghiChu: map['GhiChu']?.toString(),
      soCongNhan: parseDouble(map['SoCongNhan']),
      dinhMucTCN: parseInteger(map['DinhMucTCN']),
      congTruKhac: parseInteger(map['CongTrucKhac']),
      dinhMuc: parseInteger(map['DinhMuc']),
    );
  }
}

// 3. OrderChiTiet Model
class OrderChiTietModel {
  final String uid;
  String? orderId;
  String? itemId;
  String? ten;
  String? phanLoai;
  String? ghiChu;
  String? donVi;
  double? soLuong;
  int? donGia;
  bool? khachTra;
  int? thanhTien;

  OrderChiTietModel({
    required this.uid,
    this.orderId,
    this.itemId,
    this.ten,
    this.phanLoai,
    this.ghiChu,
    this.donVi,
    this.soLuong,
    this.donGia,
    this.khachTra,
    this.thanhTien,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'OrderID': orderId,
    'ItemID': itemId,
    'Ten': ten,
    'PhanLoai': phanLoai,
    'GhiChu': ghiChu,
    'DonVi': donVi,
    'SoLuong': soLuong,
    'DonGia': donGia,
    'KhachTra': khachTra == true ? 1 : 0, 
    'ThanhTien': thanhTien,
  };

  factory OrderChiTietModel.fromMap(Map<String, dynamic> map) { 
    int? parseInteger(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }
    return OrderChiTietModel(
    uid: map['UID'],
    orderId: map['OrderID'],
    itemId: map['ItemID'],
    ten: map['Ten'],
    phanLoai: map['PhanLoai'],
    ghiChu: map['GhiChu'],
    donVi: map['DonVi'],
    soLuong: parseDouble(map['SoLuong']),
    donGia: parseInteger(map['DonGia']),
    khachTra: map['KhachTra'] == 1,
    thanhTien: parseInteger(map['ThanhTien']),
  );
}}

// 4. ChamCongCN Model
class ChamCongCNModel {
  final String uid;
  DateTime? ngay;
  String? gio;
  String? nguoiDung;
  String? boPhan;
  String? maBP;
  String? phanLoai;
  String? maNV;
  String? congThuongChu;
  double? ngoaiGioThuong;
  double? ngoaiGioKhac;
  double? ngoaiGiox15;
  double? ngoaiGiox2;
  int? hoTro;
  int? partTime;
  int? partTimeSang;
  int? partTimeChieu;
  double? congLe;

  ChamCongCNModel({
    required this.uid,
    this.ngay,
    this.gio,
    this.nguoiDung,
    this.boPhan,
    this.maBP,
    this.phanLoai,
    this.maNV,
    this.congThuongChu,
    this.ngoaiGioThuong,
    this.ngoaiGioKhac,
    this.ngoaiGiox15,
    this.ngoaiGiox2,
    this.hoTro,
    this.partTime,
    this.partTimeSang,
    this.partTimeChieu,
    this.congLe,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'Ngay': ngay?.toIso8601String(),
    'Gio': gio,
    'NguoiDung': nguoiDung,
    'BoPhan': boPhan,
    'MaBP': maBP,
    'PhanLoai': phanLoai,
    'MaNV': maNV,
    'CongThuongChu': congThuongChu,
    'NgoaiGioThuong': ngoaiGioThuong,
    'NgoaiGioKhac': ngoaiGioKhac,
    'NgoaiGiox15': ngoaiGiox15,
    'NgoaiGiox2': ngoaiGiox2,
    'HoTro': hoTro,
    'PartTime': partTime,
    'PartTimeSang': partTimeSang,
    'PartTimeChieu': partTimeChieu,
    'CongLe': congLe,
  };

  factory ChamCongCNModel.fromMap(Map<String, dynamic> map) { 
    int? parseInteger(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }
    return ChamCongCNModel(
    uid: map['UID'],
    ngay: map['Ngay'] != null ? DateTime.parse(map['Ngay']) : null,
    gio: map['Gio'],
    nguoiDung: map['NguoiDung'],
    boPhan: map['BoPhan'],
    maBP: map['MaBP'],
    phanLoai: map['PhanLoai'],
    maNV: map['MaNV'],
    congThuongChu: map['CongThuongChu'],
    ngoaiGioThuong: parseDouble(map['NgoaiGioThuong']),
    ngoaiGioKhac: parseDouble(map['NgoaiGioKhac']),
    ngoaiGiox15: parseDouble(map['NgoaiGiox15']),
    ngoaiGiox2: parseDouble(map['NgoaiGiox2']),
    hoTro: parseInteger(map['HoTro']),
    partTime: parseInteger(map['PartTime']),
    partTimeSang: parseInteger(map['PartTimeSang']),
    partTimeChieu: parseInteger(map['PartTimeChieu']),
    congLe: parseDouble(map['CongLe']),
  );
}}
class OrderMatHangModel {
  final String itemId;
  String ten, donVi;
  int? donGia;
  String? phanLoai, phanNhom, hinhAnh;

  OrderMatHangModel({
    required this.itemId,
    required this.ten,
    required this.donVi,
    this.donGia,
    this.phanLoai,
    this.phanNhom,
    this.hinhAnh,
  });

  Map<String, dynamic> toMap() => {
    'ItemId': itemId,
    'Ten': ten,
    'DonVi': donVi,
    'DonGia': donGia,
    'PhanLoai': phanLoai,
    'PhanNhom': phanNhom,
    'HinhAnh': hinhAnh,
  };

  factory OrderMatHangModel.fromMap(Map<String, dynamic> map) {
    // Handle numeric conversion safely
    int? parseDonGia(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return OrderMatHangModel(
      itemId: map['ItemId'] ?? '',
      ten: map['Ten'] ?? '',
      donVi: map['DonVi'] ?? '',
      donGia: parseDonGia(map['DonGia']),
      phanLoai: map['PhanLoai'],
      phanNhom: map['PhanNhom'],
      hinhAnh: map['HinhAnh'],
    );
  }
}
class HinhAnhZaloModel {
  final String uid;
  DateTime? ngay;
  String? gio;
  String? boPhan;
  String? giamSat;
  String? nguoiDung;
  String? hinhAnh;
  String? khuVuc;
  String? quanTrong;

  HinhAnhZaloModel({
    required this.uid,
    this.ngay,
    this.gio,
    this.boPhan,
    this.giamSat,
    this.nguoiDung,
    this.hinhAnh,
    this.khuVuc,
    this.quanTrong,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'Ngay': ngay?.toIso8601String(),
    'Gio': gio,
    'BoPhan': boPhan,
    'GiamSat': giamSat,
    'NguoiDung': nguoiDung,
    'HinhAnh': hinhAnh,
    'KhuVuc': khuVuc,
    'QuanTrong': quanTrong,
  };

  factory HinhAnhZaloModel.fromMap(Map<String, dynamic> map) { 
    return HinhAnhZaloModel(
    uid: map['UID'],
    ngay: map['Ngay'] != null ? DateTime.parse(map['Ngay']) : null,
    gio: map['Gio'],
    boPhan: map['BoPhan'],
    giamSat: map['GiamSat'],
    nguoiDung: map['NguoiDung'],
    hinhAnh: map['HinhAnh'],
    khuVuc: map['KhuVuc'],
    quanTrong: map['QuanTrong'],
  );
}}
// HDChiTietYCMM model class
class HDChiTietYCMMModel {
  final String? uid;
  final String? soPhieuID;
  final String? phanLoai;
  final String? danhMuc;
  final String? ma;
  final String? tenVTMMTB;
  final String? donVi;
  final int? soLuong;
  final String? loaiTien;
  final int? donGia;
  final int? thanhTien;
  final String? ghiChu;
  final String? khuVucThucHien;
  final String? dienTichSuDung;
  final String? tanSuat;

  HDChiTietYCMMModel({
    this.uid,
    this.soPhieuID,
    this.phanLoai,
    this.danhMuc,
    this.ma,
    this.tenVTMMTB,
    this.donVi,
    this.soLuong,
    this.loaiTien,
    this.donGia,
    this.thanhTien,
    this.ghiChu,
    this.khuVucThucHien,
    this.dienTichSuDung,
    this.tanSuat,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'SoPhieuID': soPhieuID,
    'Phân Loại': phanLoai,
    'Danh Mục': danhMuc,
    'Mã': ma,
    'TenVTMMTB': tenVTMMTB,
    'DonVi': donVi,
    'SoLuong': soLuong,
    'LoaiTien': loaiTien,
    'DonGia': donGia,
    'ThanhTien': thanhTien,
    'GhiChu': ghiChu,
    'KhuVucThucHien': khuVucThucHien,
    'DienTichSuDung': dienTichSuDung,
    'TanSuat': tanSuat,
  };

  factory HDChiTietYCMMModel.fromMap(Map<String, dynamic> map) {
    return HDChiTietYCMMModel(
      uid: map['UID'],
      soPhieuID: map['SoPhieuID'],
      phanLoai: map['Phân Loại'],
      danhMuc: map['Danh Mục'],
      ma: map['Mã'],
      tenVTMMTB: map['TenVTMMTB'],
      donVi: map['DonVi'],
      soLuong: map['SoLuong'] != null ? int.tryParse(map['SoLuong'].toString()) : null,
      loaiTien: map['LoaiTien'],
      donGia: map['DonGia'] != null ? int.tryParse(map['DonGia'].toString()) : null,
      thanhTien: map['ThanhTien'] != null ? int.tryParse(map['ThanhTien'].toString()) : null,
      ghiChu: map['GhiChu'],
      khuVucThucHien: map['KhuVucThucHien'],
      dienTichSuDung: map['DienTichSuDung'],
      tanSuat: map['TanSuat'],
    );
  }
}

// HDDuTru model class
class HDDuTruModel {
  final String? soPhieuID;
  final String? nguoiDung;
  final String? nhanVienPhoiHop;
  final String? chiaSe;
  final String? phanLoai;
  final String? boPhan;
  final String? diaChi;
  final double? soCongNhan;
  final double? soGiamSat;
  final String? loaiHopDong;
  final DateTime? thoiGianDuKien;
  final String? khuVucThucHien;
  final String? trangThai;
  final DateTime? ngayTao;
  final DateTime? ngayCapNhat;

  HDDuTruModel({
    this.soPhieuID,
    this.nguoiDung,
    this.nhanVienPhoiHop,
    this.chiaSe,
    this.phanLoai,
    this.boPhan,
    this.diaChi,
    this.soCongNhan,
    this.soGiamSat,
    this.loaiHopDong,
    this.thoiGianDuKien,
    this.khuVucThucHien,
    this.trangThai,
    this.ngayTao,
    this.ngayCapNhat,
  });

  Map<String, dynamic> toMap() => {
    'SoPhieuID': soPhieuID,
    'NguoiDung': nguoiDung,
    'NhanVienPhoiHop': nhanVienPhoiHop,
    'ChiaSe': chiaSe,
    'PhanLoai': phanLoai,
    'BoPhan': boPhan,
    'DiaChi': diaChi,
    'SoCongNhan': soCongNhan,
    'SoGiamSat': soGiamSat,
    'LoaiHopDong': loaiHopDong,
    'ThoiGianDuKien': thoiGianDuKien?.toIso8601String(),
    'KhuVucThucHien': khuVucThucHien,
    'TrangThai': trangThai,
    'NgayTao': ngayTao?.toIso8601String(),
    'NgayCapNhat': ngayCapNhat?.toIso8601String(),
  };

  factory HDDuTruModel.fromMap(Map<String, dynamic> map) {
    return HDDuTruModel(
      soPhieuID: map['SoPhieuID'],
      nguoiDung: map['NguoiDung'],
      nhanVienPhoiHop: map['NhanVienPhoiHop'],
      chiaSe: map['ChiaSe'],
      phanLoai: map['PhanLoai'],
      boPhan: map['BoPhan'],
      diaChi: map['DiaChi'],
      soCongNhan: map['SoCongNhan'] != null ? double.tryParse(map['SoCongNhan'].toString()) : null,
      soGiamSat: map['SoGiamSat'] != null ? double.tryParse(map['SoGiamSat'].toString()) : null,
      loaiHopDong: map['LoaiHopDong'],
      thoiGianDuKien: map['ThoiGianDuKien'] != null ? DateTime.parse(map['ThoiGianDuKien']) : null,
      khuVucThucHien: map['KhuVucThucHien'],
      trangThai: map['TrangThai'],
      ngayTao: map['NgayTao'] != null ? DateTime.parse(map['NgayTao']) : null,
      ngayCapNhat: map['NgayCapNhat'] != null ? DateTime.parse(map['NgayCapNhat']) : null,
    );
  }
}

// HDYeuCauMM model class
class HDYeuCauMMModel {
  final String? soPhieuUID;
  final String? duTruID;
  final DateTime? ngayTao;
  final DateTime? ngayGui;
  final String? nguoiDung;
  final String? nhanVienPhoiHop;
  final String? boPhan;
  final String? diaChi;
  final String? phanLoai;
  final String? trangThai;
  final String? chuKyNguoiTao;
  final String? nguoiXuLy;
  final String? chuKyNguoiXuLy;
  final String? nguoiDuyet;
  final String? chuKyNguoiDuyet;
  final String? nguoiDuyet2;
  final String? chuKyNguoiDuyet2;
  final String? statusUpdate;

  HDYeuCauMMModel({
    this.soPhieuUID,
    this.duTruID,
    this.ngayTao,
    this.ngayGui,
    this.nguoiDung,
    this.nhanVienPhoiHop,
    this.boPhan,
    this.diaChi,
    this.phanLoai,
    this.trangThai,
    this.chuKyNguoiTao,
    this.nguoiXuLy,
    this.chuKyNguoiXuLy,
    this.nguoiDuyet,
    this.chuKyNguoiDuyet,
    this.nguoiDuyet2,
    this.chuKyNguoiDuyet2,
    this.statusUpdate,
  });

  Map<String, dynamic> toMap() => {
    'SoPhieuUID': soPhieuUID,
    'DuTruID': duTruID,
    'Ngaytao': ngayTao?.toIso8601String(),
    'NgayGui': ngayGui?.toIso8601String(),
    'NguoiDung': nguoiDung,
    'NhanVienPhoiHop': nhanVienPhoiHop,
    'BoPhan': boPhan,
    'DiaChi': diaChi,
    'PhanLoai': phanLoai,
    'TrangThai': trangThai,
    'ChuKyNguoiTao': chuKyNguoiTao,
    'NguoiXuLy': nguoiXuLy,
    'ChuKyNguoiXuLy': chuKyNguoiXuLy,
    'NguoiDuyet': nguoiDuyet,
    'ChuKyNguoiDuyet': chuKyNguoiDuyet,
    'NguoiDuyet2': nguoiDuyet2,
    'ChuKyNguoiDuyet2': chuKyNguoiDuyet2,
    'StatusUpdate': statusUpdate,
  };

  factory HDYeuCauMMModel.fromMap(Map<String, dynamic> map) {
    return HDYeuCauMMModel(
      soPhieuUID: map['SoPhieuUID'],
      duTruID: map['DuTruID'],
      ngayTao: map['Ngaytao'] != null ? DateTime.parse(map['Ngaytao']) : null,
      ngayGui: map['NgayGui'] != null ? DateTime.parse(map['NgayGui']) : null,
      nguoiDung: map['NguoiDung'],
      nhanVienPhoiHop: map['NhanVienPhoiHop'],
      boPhan: map['BoPhan'],
      diaChi: map['DiaChi'],
      phanLoai: map['PhanLoai'],
      trangThai: map['TrangThai'],
      chuKyNguoiTao: map['ChuKyNguoiTao'],
      nguoiXuLy: map['NguoiXuLy'],
      chuKyNguoiXuLy: map['ChuKyNguoiXuLy'],
      nguoiDuyet: map['NguoiDuyet'],
      chuKyNguoiDuyet: map['ChuKyNguoiDuyet'],
      nguoiDuyet2: map['NguoiDuyet2'],
      chuKyNguoiDuyet2: map['ChuKyNguoiDuyet2'],
      statusUpdate: map['StatusUpdate'],
    );
  }
}
// ChamCong model class
class ChamCongModel {
  final String? nguoiDung;
  final String? phanLoai;
  final String? tenGoi;
  final String? dinhVi;

  ChamCongModel({
    this.nguoiDung,
    this.phanLoai,
    this.tenGoi,
    this.dinhVi,
  });

  Map<String, dynamic> toMap() => {
    'NguoiDung': nguoiDung,
    'PhanLoai': phanLoai,
    'TenGoi': tenGoi,
    'DinhVi': dinhVi,
  };

  factory ChamCongModel.fromMap(Map<String, dynamic> map) {
    return ChamCongModel(
      nguoiDung: map['NguoiDung'],
      phanLoai: map['PhanLoai'],
      tenGoi: map['TenGoi'],
      dinhVi: map['DinhVi'],
    );
  }
}

// ChamCongGio model class
class ChamCongGioModel {
  final String? nguoiDung;
  final String? phanLoai;
  final String? gioBatDau; 
  final String? gioKetThuc;
  final double? soCong;
  final int? soPhut;

  ChamCongGioModel({
    this.nguoiDung,
    this.phanLoai,
    this.gioBatDau,
    this.gioKetThuc,
    this.soCong,
    this.soPhut,
  });

  Map<String, dynamic> toMap() => {
    'NguoiDung': nguoiDung,
    'PhanLoai': phanLoai,
    'GioBatDau': gioBatDau,
    'GioKetThuc': gioKetThuc,
    'SoCong': soCong,
    'SoPhut': soPhut,
  };

  factory ChamCongGioModel.fromMap(Map<String, dynamic> map) {
    return ChamCongGioModel(
      nguoiDung: map['NguoiDung'],
      phanLoai: map['PhanLoai'],
      gioBatDau: map['GioBatDau'],
      gioKetThuc: map['GioKetThuc'],
      soCong: map['SoCong'] != null ? double.tryParse(map['SoCong'].toString()) : null,
      soPhut: map['SoPhut'] != null ? int.tryParse(map['SoPhut'].toString()) : null,
    );
  }
}

// ChamCongLS model class
class ChamCongLSModel {
  final String? uid;
  final String? nguoiDung;
  final DateTime? ngay;
  final String? batDau; 
  final String? phanLoaiBatDau;
  final String? diemChamBatDau;
  final String? dinhViBatDau;
  final int? khoangCachBatDau;
  final String? hopLeBatDau;
  final String? hinhAnhBatDau;
  final String? trangThaiBatDau;
  final String? nguoiDuyetBatDau;
  final String? gioLamBatDau; 
  final int? diMuonBatDau;
  final String? ketThuc; 
  final String? phanLoaiKetThuc;
  final String? diemChamKetThuc;
  final String? dinhViKetThuc;
  final int? khoangCachKetThuc;
  final String? hopLeKetThuc;
  final String? hinhAnhKetThuc;
  final String? trangThaiKetThuc;
  final String? nguoiDuyetKetThuc;
  final String? gioLamKetThuc; 
  final int? diMuonKetThuc;
  final DateTime? ngay2;
  final int? tongDiMuonNgay;
  final double? tongCongNgay;

  ChamCongLSModel({
    this.uid,
    this.nguoiDung,
    this.ngay,
    this.batDau,
    this.phanLoaiBatDau,
    this.diemChamBatDau,
    this.dinhViBatDau,
    this.khoangCachBatDau,
    this.hopLeBatDau,
    this.hinhAnhBatDau,
    this.trangThaiBatDau,
    this.nguoiDuyetBatDau,
    this.gioLamBatDau,
    this.diMuonBatDau,
    this.ketThuc,
    this.phanLoaiKetThuc,
    this.diemChamKetThuc,
    this.dinhViKetThuc,
    this.khoangCachKetThuc,
    this.hopLeKetThuc,
    this.hinhAnhKetThuc,
    this.trangThaiKetThuc,
    this.nguoiDuyetKetThuc,
    this.gioLamKetThuc,
    this.diMuonKetThuc,
    this.ngay2,
    this.tongDiMuonNgay,
    this.tongCongNgay,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'NguoiDung': nguoiDung,
    'Ngay': ngay?.toIso8601String(),
    'BatDau': batDau,
    'PhanLoaiBatDau': phanLoaiBatDau,
    'DiemChamBatDau': diemChamBatDau,
    'DinhViBatDau': dinhViBatDau,
    'KhoangCachBatDau': khoangCachBatDau,
    'HopLeBatDau': hopLeBatDau,
    'HinhAnhBatDau': hinhAnhBatDau,
    'TrangThaiBatDau': trangThaiBatDau,
    'NguoiDuyetBatDau': nguoiDuyetBatDau,
    'GioLamBatDau': gioLamBatDau,
    'DiMuonBatDau': diMuonBatDau,
    'KetThuc': ketThuc,
    'PhanLoaiKetThuc': phanLoaiKetThuc,
    'DiemChamKetThuc': diemChamKetThuc,
    'DinhViKetThuc': dinhViKetThuc,
    'KhoangCachKetThuc': khoangCachKetThuc,
    'HopLeKetThuc': hopLeKetThuc,
    'HinhAnhKetThuc': hinhAnhKetThuc,
    'TrangThaiKetThuc': trangThaiKetThuc,
    'NguoiDuyetKetThuc': nguoiDuyetKetThuc,
    'GioLamKetThuc': gioLamKetThuc,
    'DiMuonKetThuc': diMuonKetThuc,
    'Ngay2': ngay2?.toIso8601String(),
    'TongDiMuonNgay': tongDiMuonNgay,
    'TongCongNgay': tongCongNgay,
  };

  factory ChamCongLSModel.fromMap(Map<String, dynamic> map) {
    return ChamCongLSModel(
      uid: map['UID'],
      nguoiDung: map['NguoiDung'],
      ngay: map['Ngay'] != null ? DateTime.parse(map['Ngay']) : null,
      batDau: map['BatDau'],
      phanLoaiBatDau: map['PhanLoaiBatDau'],
      diemChamBatDau: map['DiemChamBatDau'],
      dinhViBatDau: map['DinhViBatDau'],
      khoangCachBatDau: map['KhoangCachBatDau'] != null ? int.tryParse(map['KhoangCachBatDau'].toString()) : null,
      hopLeBatDau: map['HopLeBatDau'],
      hinhAnhBatDau: map['HinhAnhBatDau'],
      trangThaiBatDau: map['TrangThaiBatDau'],
      nguoiDuyetBatDau: map['NguoiDuyetBatDau'],
      gioLamBatDau: map['GioLamBatDau'],
      diMuonBatDau: map['DiMuonBatDau'] != null ? int.tryParse(map['DiMuonBatDau'].toString()) : null,
      ketThuc: map['KetThuc'],
      phanLoaiKetThuc: map['PhanLoaiKetThuc'],
      diemChamKetThuc: map['DiemChamKetThuc'],
      dinhViKetThuc: map['DinhViKetThuc'],
      khoangCachKetThuc: map['KhoangCachKetThuc'] != null ? int.tryParse(map['KhoangCachKetThuc'].toString()) : null,
      hopLeKetThuc: map['HopLeKetThuc'],
      hinhAnhKetThuc: map['HinhAnhKetThuc'],
      trangThaiKetThuc: map['TrangThaiKetThuc'],
      nguoiDuyetKetThuc: map['NguoiDuyetKetThuc'],
      gioLamKetThuc: map['GioLamKetThuc'],
      diMuonKetThuc: map['DiMuonKetThuc'] != null ? int.tryParse(map['DiMuonKetThuc'].toString()) : null,
      ngay2: map['Ngay2'] != null ? DateTime.parse(map['Ngay2']) : null,
      tongDiMuonNgay: map['TongDiMuonNgay'] != null ? int.tryParse(map['TongDiMuonNgay'].toString()) : null,
      tongCongNgay: map['TongCongNgay'] != null ? double.tryParse(map['TongCongNgay'].toString()) : null,
    );
  }
}
class ChamCongCNThangModel {
  final String? uid;
  final DateTime? ngayCapNhat;
  final DateTime? giaiDoan;
  final String? maNV;
  final String? boPhan;
  final String? maBP;
  final String? phanLoaiDacBiet;
  final String? ghiChu;
  final int? congChuanToiDa;
  final String? xepLoaiTuDong;
  final double? tuan1va2;
  final double? phep1va2;
  final double? ht1va2;
  final double? tuan3va4;
  final double? phep3va4;
  final double? ht3va4;
  final double? tongCong;
  final double? tongPhep;
  final double? tongLe;
  final double? tongNgoaiGio;
  final double? tongHV;
  final double? tongDem;
  final double? tongCD;
  final double? tongHT;
  final int? tongLuong;
  final int? ungLan1;
  final int? ungLan2;
  final int? thanhToan3;
  final int? truyLinh;
  final int? truyThu;
  final int? khac;
  final int? mucLuongThang;
  final int? mucLuongNgoaiGio;
  final int? mucLuongNgoaiGio2;

  ChamCongCNThangModel({
    this.uid,
    this.ngayCapNhat,
    this.giaiDoan,
    this.maNV,
    this.boPhan,
    this.maBP,
    this.phanLoaiDacBiet,
    this.ghiChu,
    this.congChuanToiDa,
    this.xepLoaiTuDong,
    this.tuan1va2,
    this.phep1va2,
    this.ht1va2,
    this.tuan3va4,
    this.phep3va4,
    this.ht3va4,
    this.tongCong,
    this.tongPhep,
    this.tongLe,
    this.tongNgoaiGio,
    this.tongHV,
    this.tongDem,
    this.tongCD,
    this.tongHT,
    this.tongLuong,
    this.ungLan1,
    this.ungLan2,
    this.thanhToan3,
    this.truyLinh,
    this.truyThu,
    this.khac,
    this.mucLuongThang,
    this.mucLuongNgoaiGio,
    this.mucLuongNgoaiGio2,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'NgayCapNhat': ngayCapNhat?.toIso8601String(),
    'GiaiDoan': giaiDoan?.toIso8601String(),
    'MaNV': maNV,
    'BoPhan': boPhan,
    'MaBP': maBP,
    'PhanLoaiDacBiet': phanLoaiDacBiet,
    'GhiChu': ghiChu,
    'CongChuanToiDa': congChuanToiDa,
    'XepLoaiTuDong': xepLoaiTuDong,
    'Tuan_1va2': tuan1va2,  // Changed from '1va2_Tuan'
    'Phep_1va2': phep1va2,  // Changed from '1va2_Phep'
    'HT_1va2': ht1va2,      // Changed from '1va2_HT'
    'Tuan_3va4': tuan3va4,  // Changed from '3va4_Tuan'
    'Phep_3va4': phep3va4,  // Changed from '3va4_Phep'
    'HT_3va4': ht3va4,      // Changed from '3va4_HT'
    'Tong_Cong': tongCong,
    'Tong_Phep': tongPhep,
    'Tong_Le': tongLe,
    'Tong_NgoaiGio': tongNgoaiGio,
    'Tong_HV': tongHV,
    'Tong_Dem': tongDem,
    'Tong_CD': tongCD,
    'Tong_HT': tongHT,
    'TongLuong': tongLuong,
    'UngLan1': ungLan1,
    'UngLan2': ungLan2,
    'ThanhToan3': thanhToan3,
    'TruyLinh': truyLinh,
    'TruyThu': truyThu,
    'Khac': khac,
    'MucLuongThang': mucLuongThang,
    'MucLuongNgoaiGio': mucLuongNgoaiGio,
    'MucLuongNgoaiGio2': mucLuongNgoaiGio2,
  };

  factory ChamCongCNThangModel.fromMap(Map<String, dynamic> map) {
    return ChamCongCNThangModel(
      uid: map['UID'],
      ngayCapNhat: map['NgayCapNhat'] != null ? DateTime.parse(map['NgayCapNhat']) : null,
      giaiDoan: map['GiaiDoan'] != null ? DateTime.parse(map['GiaiDoan']) : null,
      maNV: map['MaNV'],
      boPhan: map['BoPhan'],
      maBP: map['MaBP'],
      phanLoaiDacBiet: map['PhanLoaiDacBiet'],
      ghiChu: map['GhiChu'],
      congChuanToiDa: map['CongChuanToiDa'] != null ? int.tryParse(map['CongChuanToiDa'].toString()) : null,
      xepLoaiTuDong: map['XepLoaiTuDong'],
      tuan1va2: map['Tuan_1va2'] != null ? double.tryParse(map['Tuan_1va2'].toString()) : null,  // Changed
      phep1va2: map['Phep_1va2'] != null ? double.tryParse(map['Phep_1va2'].toString()) : null,  // Changed
      ht1va2: map['HT_1va2'] != null ? double.tryParse(map['HT_1va2'].toString()) : null,        // Changed
      tuan3va4: map['Tuan_3va4'] != null ? double.tryParse(map['Tuan_3va4'].toString()) : null,  // Changed
      phep3va4: map['Phep_3va4'] != null ? double.tryParse(map['Phep_3va4'].toString()) : null,  // Changed
      ht3va4: map['HT_3va4'] != null ? double.tryParse(map['HT_3va4'].toString()) : null,        // Changed
      tongCong: map['Tong_Cong'] != null ? double.tryParse(map['Tong_Cong'].toString()) : null,
      tongPhep: map['Tong_Phep'] != null ? double.tryParse(map['Tong_Phep'].toString()) : null,
      tongLe: map['Tong_Le'] != null ? double.tryParse(map['Tong_Le'].toString()) : null,
      tongNgoaiGio: map['Tong_NgoaiGio'] != null ? double.tryParse(map['Tong_NgoaiGio'].toString()) : null,
      tongHV: map['Tong_HV'] != null ? double.tryParse(map['Tong_HV'].toString()) : null,
      tongDem: map['Tong_Dem'] != null ? double.tryParse(map['Tong_Dem'].toString()) : null,
      tongCD: map['Tong_CD'] != null ? double.tryParse(map['Tong_CD'].toString()) : null,
      tongHT: map['Tong_HT'] != null ? double.tryParse(map['Tong_HT'].toString()) : null,
      tongLuong: map['TongLuong'] != null ? int.tryParse(map['TongLuong'].toString()) : null,
      ungLan1: map['UngLan1'] != null ? int.tryParse(map['UngLan1'].toString()) : null,
      ungLan2: map['UngLan2'] != null ? int.tryParse(map['UngLan2'].toString()) : null,
      thanhToan3: map['ThanhToan3'] != null ? int.tryParse(map['ThanhToan3'].toString()) : null,
      truyLinh: map['TruyLinh'] != null ? int.tryParse(map['TruyLinh'].toString()) : null,
      truyThu: map['TruyThu'] != null ? int.tryParse(map['TruyThu'].toString()) : null,
      khac: map['Khac'] != null ? int.tryParse(map['Khac'].toString()) : null,
      mucLuongThang: map['MucLuongThang'] != null ? int.tryParse(map['MucLuongThang'].toString()) : null,
      mucLuongNgoaiGio: map['MucLuongNgoaiGio'] != null ? int.tryParse(map['MucLuongNgoaiGio'].toString()) : null,
      mucLuongNgoaiGio2: map['MucLuongNgoaiGio2'] != null ? int.tryParse(map['MucLuongNgoaiGio2'].toString()) : null,
    );
  }
}
class ChamCongVangNghiTcaModel {
  final String? uid;
  final String? nguoiDung;
  final String? phanLoai;
  final DateTime? ngayBatDau;
  final DateTime? ngayKetThuc;
  final String? ghiChu;
  final String? truongHop;
  final String? nguoiDuyet;
  final String? trangThai;
  final double? giaTriNgay;

  ChamCongVangNghiTcaModel({
    this.uid,
    this.nguoiDung,
    this.phanLoai,
    this.ngayBatDau,
    this.ngayKetThuc,
    this.ghiChu,
    this.truongHop,
    this.nguoiDuyet,
    this.trangThai,
    this.giaTriNgay,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'NguoiDung': nguoiDung,
    'PhanLoai': phanLoai,
    'NgayBatDau': ngayBatDau?.toIso8601String(),
    'NgayKetThuc': ngayKetThuc?.toIso8601String(),
    'GhiChu': ghiChu,
    'TruongHop': truongHop,
    'NguoiDuyet': nguoiDuyet,
    'TrangThai': trangThai,
    'GiaTriNgay': giaTriNgay,
  };

  factory ChamCongVangNghiTcaModel.fromMap(Map<String, dynamic> map) {
    return ChamCongVangNghiTcaModel(
      uid: map['UID'],
      nguoiDung: map['NguoiDung'],
      phanLoai: map['PhanLoai'],
      ngayBatDau: map['NgayBatDau'] != null ? DateTime.parse(map['NgayBatDau']) : null,
      ngayKetThuc: map['NgayKetThuc'] != null ? DateTime.parse(map['NgayKetThuc']) : null,
      ghiChu: map['GhiChu'],
      truongHop: map['TruongHop'],
      nguoiDuyet: map['NguoiDuyet'],
      trangThai: map['TrangThai'],
      giaTriNgay: map['GiaTriNgay'] != null ? double.tryParse(map['GiaTriNgay'].toString()) : null,
    );
  }
}
class MapListModel {
  final String? mapUID;
  final String? nguoiDung;
  final String? boPhan;
  final String? tenBanDo;
  final String? hinhAnhBanDo;
  final double? chieuDaiMet;
  final double? chieuCaoMet;

  MapListModel({
    this.mapUID,
    this.nguoiDung,
    this.boPhan,
    this.tenBanDo,
    this.hinhAnhBanDo,
    this.chieuDaiMet,
    this.chieuCaoMet,
  });

  Map<String, dynamic> toMap() => {
    'mapUID': mapUID,
    'nguoiDung': nguoiDung,
    'boPhan': boPhan,
    'tenBanDo': tenBanDo,
    'hinhAnhBanDo': hinhAnhBanDo,
    'chieuDaiMet': chieuDaiMet,
    'chieuCaoMet': chieuCaoMet,
  };

  factory MapListModel.fromMap(Map<String, dynamic> map) {
    return MapListModel(
      mapUID: map['mapUID'],
      nguoiDung: map['nguoiDung'],
      boPhan: map['boPhan'],
      tenBanDo: map['tenBanDo'],
      hinhAnhBanDo: map['hinhAnhBanDo'],
      chieuDaiMet: map['chieuDaiMet'] != null ? double.tryParse(map['chieuDaiMet'].toString()) : null,
      chieuCaoMet: map['chieuCaoMet'] != null ? double.tryParse(map['chieuCaoMet'].toString()) : null,
    );
  }
}

class MapFloorModel {
  final String? floorUID;
  final String? mapUID;
  final String? tenTang;
  final String? hinhAnhTang;
  final double? chieuDaiMet;
  final double? chieuCaoMet;
  final double? offsetX;
  final double? offsetY;

  MapFloorModel({
    this.floorUID,
    this.mapUID,
    this.tenTang,
    this.hinhAnhTang,
    this.chieuDaiMet,
    this.chieuCaoMet,
    this.offsetX,
    this.offsetY,
  });

  Map<String, dynamic> toMap() => {
    'floorUID': floorUID,
    'mapUID': mapUID,
    'tenTang': tenTang,
    'hinhAnhTang': hinhAnhTang,
    'chieuDaiMet': chieuDaiMet,
    'chieuCaoMet': chieuCaoMet,
    'offsetX': offsetX,
    'offsetY': offsetY,
  };

  factory MapFloorModel.fromMap(Map<String, dynamic> map) {
    return MapFloorModel(
      floorUID: map['floorUID'],
      mapUID: map['mapUID'],
      tenTang: map['tenTang'],
      hinhAnhTang: map['hinhAnhTang'],
      chieuDaiMet: map['chieuDaiMet'] != null ? double.tryParse(map['chieuDaiMet'].toString()) : null,
      chieuCaoMet: map['chieuCaoMet'] != null ? double.tryParse(map['chieuCaoMet'].toString()) : null,
      offsetX: map['offsetX'] != null ? double.tryParse(map['offsetX'].toString()) : null,
      offsetY: map['offsetY'] != null ? double.tryParse(map['offsetY'].toString()) : null,
    );
  }
}

class MapZoneModel {
  final String? zoneUID;
  final String? floorUID;
  final String? tenKhuVuc;
  final String? cacDiemMoc;
  final String? mauSac;

  MapZoneModel({
    this.zoneUID,
    this.floorUID,
    this.tenKhuVuc,
    this.cacDiemMoc,
    this.mauSac,
  });

  Map<String, dynamic> toMap() => {
    'zoneUID': zoneUID,
    'floorUID': floorUID,
    'tenKhuVuc': tenKhuVuc,
    'cacDiemMoc': cacDiemMoc,
    'mauSac': mauSac,
  };

  factory MapZoneModel.fromMap(Map<String, dynamic> map) {
    return MapZoneModel(
      zoneUID: map['zoneUID'],
      floorUID: map['floorUID'],
      tenKhuVuc: map['tenKhuVuc'],
      cacDiemMoc: map['cacDiemMoc'],
      mauSac: map['mauSac'],
    );
  }
}
class CoinModel {
  final String? uid;
  final String? nguoiDung;
  final String? ngay;
  final int? soLuong;
  final int? tongTien;

  CoinModel({
    this.uid,
    this.nguoiDung,
    this.ngay,
    this.soLuong,
    this.tongTien,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nguoiDung': nguoiDung,
    'ngay': ngay,
    'soLuong': soLuong,
    'tongTien': tongTien,
  };

  factory CoinModel.fromMap(Map<String, dynamic> map) {
    return CoinModel(
      uid: map['uid'],
      nguoiDung: map['nguoiDung'],
      ngay: map['ngay'],
      soLuong: map['soLuong'] != null ? int.tryParse(map['soLuong'].toString()) : null,
      tongTien: map['tongTien'] != null ? int.tryParse(map['tongTien'].toString()) : null,
    );
  }
}

class CoinRateModel {
  final String? uid;
  final String? caseType;
  final int? startRate;
  final int? endRate;
  final int? maxCount;

  CoinRateModel({
    this.uid,
    this.caseType,
    this.startRate,
    this.endRate,
    this.maxCount,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'caseType': caseType,
    'startRate': startRate,
    'endRate': endRate,
    'maxCount': maxCount,
  };

  factory CoinRateModel.fromMap(Map<String, dynamic> map) {
    return CoinRateModel(
      uid: map['uid'],
      caseType: map['caseType'],
      startRate: map['startRate'] != null ? int.tryParse(map['startRate'].toString()) : null,
      endRate: map['endRate'] != null ? int.tryParse(map['endRate'].toString()) : null,
      maxCount: map['maxCount'] != null ? int.tryParse(map['maxCount'].toString()) : null,
    );
  }
}
class MapStaffModel {
  final String? uid;
  final String? mapProject;
  final String? nguoiDung;
  final String? hoTen;
  final String? vaiTro;

  MapStaffModel({
    this.uid,
    this.mapProject,
    this.nguoiDung,
    this.hoTen,
    this.vaiTro,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'mapProject': mapProject,
    'nguoiDung': nguoiDung,
    'hoTen': hoTen,
    'vaiTro': vaiTro,
  };

  factory MapStaffModel.fromMap(Map<String, dynamic> map) {
    return MapStaffModel(
      uid: map['uid'],
      mapProject: map['mapProject'],
      nguoiDung: map['nguoiDung'],
      hoTen: map['hoTen'],
      vaiTro: map['vaiTro'],
    );
  }
}

class MapPositionModel {
  final String? uid;
  final String? mapList;
  final String? mapFloor;
  final String? mapZone;
  final String? viTri;

  MapPositionModel({
    this.uid,
    this.mapList,
    this.mapFloor,
    this.mapZone,
    this.viTri,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'mapList': mapList,
    'mapFloor': mapFloor,
    'mapZone': mapZone,
    'viTri': viTri,
  };

  factory MapPositionModel.fromMap(Map<String, dynamic> map) {
    return MapPositionModel(
      uid: map['uid'],
      mapList: map['mapList'],
      mapFloor: map['mapFloor'],
      mapZone: map['mapZone'],
      viTri: map['viTri'],
    );
  }
}
class DonHangModel {
  final String? soPhieu;
  final String? nguoiTao;
  final String? ngay;
  final String? tenKhachHang;
  final String? sdtKhachHang;
  final String? soPO;
  final String? diaChi;
  final String? mst;
  final String? tapKH;
  final String? tenNguoiGiaoDich;
  final String? boPhanGiaoDich;
  final String? sdtNguoiGiaoDich;
  final String? thoiGianDatHang;
  final String? ngayYeuCauGiao;
  final String? thoiGianCapNhatTrangThai;
  final String? phuongThucThanhToan;
  final int? thanhToanSauNhanHangXNgay;
  final int? datCocSauXNgay;
  final String? giayToCanKhiGiaoHang;
  final String? thoiGianVietHoaDon;
  final String? thongTinVietHoaDon;
  final String? diaChiGiaoHang;
  final String? hoTenNguoiNhanHoaHong;
  final String? sdtNguoiNhanHoaHong;
  final String? hinhThucChuyenHoaHong;
  final String? thongTinNhanHoaHong;
  final String? ngaySeGiao;
  final String? thoiGianCapNhatMoiNhat;
  final String? phuongThucGiaoHang;
  final String? phuongTienGiaoHang;
  final String? hoTenNguoiGiaoHang;
  final String? ghiChu;
  final int? giaNet;
  final int? tongTien;
  final int? vat10;
  final int? tongCong;
  final int? hoaHong10;
  final int? tienGui10;
  final int? thueTNDN;
  final int? vanChuyen;
  final int? thucThu;
  final String? nguoiNhanHang;
  final String? sdtNguoiNhanHang;
  final String? phieuXuatKho;
  final String? trangThai;
  final String? tenKhachHang2;

  DonHangModel({
    this.soPhieu,
    this.nguoiTao,
    this.ngay,
    this.tenKhachHang,
    this.sdtKhachHang,
    this.soPO,
    this.diaChi,
    this.mst,
    this.tapKH,
    this.tenNguoiGiaoDich,
    this.boPhanGiaoDich,
    this.sdtNguoiGiaoDich,
    this.thoiGianDatHang,
    this.ngayYeuCauGiao,
    this.thoiGianCapNhatTrangThai,
    this.phuongThucThanhToan,
    this.thanhToanSauNhanHangXNgay,
    this.datCocSauXNgay,
    this.giayToCanKhiGiaoHang,
    this.thoiGianVietHoaDon,
    this.thongTinVietHoaDon,
    this.diaChiGiaoHang,
    this.hoTenNguoiNhanHoaHong,
    this.sdtNguoiNhanHoaHong,
    this.hinhThucChuyenHoaHong,
    this.thongTinNhanHoaHong,
    this.ngaySeGiao,
    this.thoiGianCapNhatMoiNhat,
    this.phuongThucGiaoHang,
    this.phuongTienGiaoHang,
    this.hoTenNguoiGiaoHang,
    this.ghiChu,
    this.giaNet,
    this.tongTien,
    this.vat10,
    this.tongCong,
    this.hoaHong10,
    this.tienGui10,
    this.thueTNDN,
    this.vanChuyen,
    this.thucThu,
    this.nguoiNhanHang,
    this.sdtNguoiNhanHang,
    this.phieuXuatKho,
    this.trangThai,
    this.tenKhachHang2,
  });

  Map<String, dynamic> toMap() => {
    'soPhieu': soPhieu,
    'nguoiTao': nguoiTao,
    'ngay': ngay,
    'tenKhachHang': tenKhachHang,
    'sdtKhachHang': sdtKhachHang,
    'soPO': soPO,
    'diaChi': diaChi,
    'mst': mst,
    'tapKH': tapKH,
    'tenNguoiGiaoDich': tenNguoiGiaoDich,
    'boPhanGiaoDich': boPhanGiaoDich,
    'sdtNguoiGiaoDich': sdtNguoiGiaoDich,
    'thoiGianDatHang': thoiGianDatHang,
    'ngayYeuCauGiao': ngayYeuCauGiao,
    'thoiGianCapNhatTrangThai': thoiGianCapNhatTrangThai,
    'phuongThucThanhToan': phuongThucThanhToan,
    'thanhToanSauNhanHangXNgay': thanhToanSauNhanHangXNgay,
    'datCocSauXNgay': datCocSauXNgay,
    'giayToCanKhiGiaoHang': giayToCanKhiGiaoHang,
    'thoiGianVietHoaDon': thoiGianVietHoaDon,
    'thongTinVietHoaDon': thongTinVietHoaDon,
    'diaChiGiaoHang': diaChiGiaoHang,
    'hoTenNguoiNhanHoaHong': hoTenNguoiNhanHoaHong,
    'sdtNguoiNhanHoaHong': sdtNguoiNhanHoaHong,
    'hinhThucChuyenHoaHong': hinhThucChuyenHoaHong,
    'thongTinNhanHoaHong': thongTinNhanHoaHong,
    'ngaySeGiao': ngaySeGiao,
    'thoiGianCapNhatMoiNhat': thoiGianCapNhatMoiNhat,
    'phuongThucGiaoHang': phuongThucGiaoHang,
    'phuongTienGiaoHang': phuongTienGiaoHang,
    'hoTenNguoiGiaoHang': hoTenNguoiGiaoHang,
    'ghiChu': ghiChu,
    'giaNet': giaNet,
    'tongTien': tongTien,
    'vat10': vat10,
    'tongCong': tongCong,
    'hoaHong10': hoaHong10,
    'tienGui10': tienGui10,
    'thueTNDN': thueTNDN,
    'vanChuyen': vanChuyen,
    'thucThu': thucThu,
    'nguoiNhanHang': nguoiNhanHang,
    'sdtNguoiNhanHang': sdtNguoiNhanHang,
    'phieuXuatKho': phieuXuatKho,
    'trangThai': trangThai,
    'tenKhachHang2': tenKhachHang2,
  };

  factory DonHangModel.fromMap(Map<String, dynamic> map) {
    return DonHangModel(
      soPhieu: map['soPhieu'],
      nguoiTao: map['nguoiTao'],
      ngay: map['ngay'],
      tenKhachHang: map['tenKhachHang'],
      sdtKhachHang: map['sdtKhachHang'],
      soPO: map['soPO'],
      diaChi: map['diaChi'],
      mst: map['mst'],
      tapKH: map['tapKH'],
      tenNguoiGiaoDich: map['tenNguoiGiaoDich'],
      boPhanGiaoDich: map['boPhanGiaoDich'],
      sdtNguoiGiaoDich: map['sdtNguoiGiaoDich'],
      thoiGianDatHang: map['thoiGianDatHang'],
      ngayYeuCauGiao: map['ngayYeuCauGiao'],
      thoiGianCapNhatTrangThai: map['thoiGianCapNhatTrangThai'],
      phuongThucThanhToan: map['phuongThucThanhToan'],
      thanhToanSauNhanHangXNgay: map['thanhToanSauNhanHangXNgay'] != null ? int.tryParse(map['thanhToanSauNhanHangXNgay'].toString()) : null,
      datCocSauXNgay: map['datCocSauXNgay'] != null ? int.tryParse(map['datCocSauXNgay'].toString()) : null,
      giayToCanKhiGiaoHang: map['giayToCanKhiGiaoHang'],
      thoiGianVietHoaDon: map['thoiGianVietHoaDon'],
      thongTinVietHoaDon: map['thongTinVietHoaDon'],
      diaChiGiaoHang: map['diaChiGiaoHang'],
      hoTenNguoiNhanHoaHong: map['hoTenNguoiNhanHoaHong'],
      sdtNguoiNhanHoaHong: map['sdtNguoiNhanHoaHong'],
      hinhThucChuyenHoaHong: map['hinhThucChuyenHoaHong'],
      thongTinNhanHoaHong: map['thongTinNhanHoaHong'],
      ngaySeGiao: map['ngaySeGiao'],
      thoiGianCapNhatMoiNhat: map['thoiGianCapNhatMoiNhat'],
      phuongThucGiaoHang: map['phuongThucGiaoHang'],
      phuongTienGiaoHang: map['phuongTienGiaoHang'],
      hoTenNguoiGiaoHang: map['hoTenNguoiGiaoHang'],
      ghiChu: map['ghiChu'],
      giaNet: map['giaNet'] != null ? int.tryParse(map['giaNet'].toString()) : null,
      tongTien: map['tongTien'] != null ? int.tryParse(map['tongTien'].toString()) : null,
      vat10: map['vat10'] != null ? int.tryParse(map['vat10'].toString()) : null,
      tongCong: map['tongCong'] != null ? int.tryParse(map['tongCong'].toString()) : null,
      hoaHong10: map['hoaHong10'] != null ? int.tryParse(map['hoaHong10'].toString()) : null,
      tienGui10: map['tienGui10'] != null ? int.tryParse(map['tienGui10'].toString()) : null,
      thueTNDN: map['thueTNDN'] != null ? int.tryParse(map['thueTNDN'].toString()) : null,
      vanChuyen: map['vanChuyen'] != null ? int.tryParse(map['vanChuyen'].toString()) : null,
      thucThu: map['thucThu'] != null ? int.tryParse(map['thucThu'].toString()) : null,
      nguoiNhanHang: map['nguoiNhanHang'],
      sdtNguoiNhanHang: map['sdtNguoiNhanHang'],
      phieuXuatKho: map['phieuXuatKho'],
      trangThai: map['trangThai'],
      tenKhachHang2: map['tenKhachHang2'],
    );
  }
}

class ChiTietDonModel {
  final String? uid;
  final String? soPhieu;
  final String? trangThai;
  final String? tenHang;
  final String? maHang;
  final String? donViTinh;
  final double? soLuongYeuCau;
  final int? donGia;
  final int? thanhTien;
  final double? soLuongThucGiao;
  final String? chiNhanh;
  final String? idHang;
  final double? soLuongKhachNhan;
  final String? duyet;
  final String? xuatXuHangKhac;
  final String? baoGia;
  final String? hinhAnh;
  final String? ghiChu;
  final int? phanTramVAT;
  final int? vat;
  final String? tenKhachHang;
  final String? updateTime;

  ChiTietDonModel({
    this.uid,
    this.soPhieu,
    this.trangThai,
    this.tenHang,
    this.maHang,
    this.donViTinh,
    this.soLuongYeuCau,
    this.donGia,
    this.thanhTien,
    this.soLuongThucGiao,
    this.chiNhanh,
    this.idHang,
    this.soLuongKhachNhan,
    this.duyet,
    this.xuatXuHangKhac,
    this.baoGia,
    this.hinhAnh,
    this.ghiChu,
    this.phanTramVAT,
    this.vat,
    this.tenKhachHang,
    this.updateTime,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'soPhieu': soPhieu,
    'trangThai': trangThai,
    'tenHang': tenHang,
    'maHang': maHang,
    'donViTinh': donViTinh,
    'soLuongYeuCau': soLuongYeuCau,
    'donGia': donGia,
    'thanhTien': thanhTien,
    'soLuongThucGiao': soLuongThucGiao,
    'chiNhanh': chiNhanh,
    'idHang': idHang,
    'soLuongKhachNhan': soLuongKhachNhan,
    'duyet': duyet,
    'xuatXuHangKhac': xuatXuHangKhac,
    'baoGia': baoGia,
    'hinhAnh': hinhAnh,
    'ghiChu': ghiChu,
    'phanTramVAT': phanTramVAT,
    'vat': vat,
    'tenKhachHang': tenKhachHang,
    'updateTime': updateTime,
  };

  factory ChiTietDonModel.fromMap(Map<String, dynamic> map) {
    return ChiTietDonModel(
      uid: map['uid'],
      soPhieu: map['soPhieu'],
      trangThai: map['trangThai'],
      tenHang: map['tenHang'],
      maHang: map['maHang'],
      donViTinh: map['donViTinh'],
      soLuongYeuCau: map['soLuongYeuCau'] != null ? double.tryParse(map['soLuongYeuCau'].toString()) : null,
      donGia: map['donGia'] != null ? int.tryParse(map['donGia'].toString()) : null,
      thanhTien: map['thanhTien'] != null ? int.tryParse(map['thanhTien'].toString()) : null,
      soLuongThucGiao: map['soLuongThucGiao'] != null ? double.tryParse(map['soLuongThucGiao'].toString()) : null,
      chiNhanh: map['chiNhanh'],
      idHang: map['idHang'],
      soLuongKhachNhan: map['soLuongKhachNhan'] != null ? double.tryParse(map['soLuongKhachNhan'].toString()) : null,
      duyet: map['duyet'],
      xuatXuHangKhac: map['xuatXuHangKhac'],
      baoGia: map['baoGia'],
      hinhAnh: map['hinhAnh'],
      ghiChu: map['ghiChu'],
      phanTramVAT: map['phanTramVAT'] != null ? int.tryParse(map['phanTramVAT'].toString()) : null,
      vat: map['vat'] != null ? int.tryParse(map['vat'].toString()) : null,
      tenKhachHang: map['tenKhachHang'],
      updateTime: map['updateTime'],
    );
  }
}
class DSHangModel {
  final String? uid;
  final String? sku;
  final int? counter;
  final String? maNhapKho;
  final String? tenModel;
  final String? tenSanPham;
  final String? sanPhamGoc;
  final String? phanLoai1;
  final String? congDung;
  final String? chatLieu;
  final String? mauSac;
  final String? kichThuoc;
  final String? dungTich;
  final String? khoiLuong;
  final String? quyCachDongGoi;
  final String? soLuongDongGoi;
  final String? donVi;
  final String? kichThuocDongGoi;
  final String? thuongHieu;
  final String? nhaCungCap;
  final String? xuatXu;
  final String? moTa;
  final String? hinhAnh;
  final bool? hangTieuHao;
  final bool? coThoiHan;
  final String? thoiHanSuDung;

  DSHangModel({
    this.uid,
    this.sku,
    this.counter,
    this.maNhapKho,
    this.tenModel,
    this.tenSanPham,
    this.sanPhamGoc,
    this.phanLoai1,
    this.congDung,
    this.chatLieu,
    this.mauSac,
    this.kichThuoc,
    this.dungTich,
    this.khoiLuong,
    this.quyCachDongGoi,
    this.soLuongDongGoi,
    this.donVi,
    this.kichThuocDongGoi,
    this.thuongHieu,
    this.nhaCungCap,
    this.xuatXu,
    this.moTa,
    this.hinhAnh,
    this.hangTieuHao,
    this.coThoiHan,
    this.thoiHanSuDung,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'SKU': sku,
    'Counter': counter,
    'MaNhapKho': maNhapKho,
    'TenModel': tenModel,
    'TenSanPham': tenSanPham,
    'SanPhamGoc': sanPhamGoc,
    'PhanLoai1': phanLoai1,
    'CongDung': congDung,
    'ChatLieu': chatLieu,
    'MauSac': mauSac,
    'KichThuoc': kichThuoc,
    'DungTich': dungTich,
    'KhoiLuong': khoiLuong,
    'QuyCachDongGoi': quyCachDongGoi,
    'SoLuongDongGoi': soLuongDongGoi,
    'DonVi': donVi,
    'KichThuocDongGoi': kichThuocDongGoi,
    'ThuongHieu': thuongHieu,
    'NhaCungCap': nhaCungCap,
    'XuatXu': xuatXu,
    'MoTa': moTa,
    'HinhAnh': hinhAnh,
    'HangTieuHao': hangTieuHao,
    'CoThoiHan': coThoiHan,
    'ThoiHanSuDung': thoiHanSuDung,
  };

  factory DSHangModel.fromMap(Map<String, dynamic> map) {
  // Function to safely get a value with case-insensitive key matching
  dynamic getValue(String key) {
    // Try all possible case variations
    final variations = [
      key,                    // As provided
      key.toLowerCase(),      // lowercase
      key.toUpperCase(),      // UPPERCASE
      key[0].toUpperCase() + key.substring(1).toLowerCase() // Title Case
    ];
    
    for (var variation in variations) {
      if (map.containsKey(variation)) {
        return map[variation];
      }
    }
    
    // If not found, try with more complex camelCase or PascalCase matching
    if (key.length > 1) {
      final keyLower = key.toLowerCase();
      for (var mapKey in map.keys) {
        if (mapKey.toLowerCase() == keyLower) {
          return map[mapKey];
        }
      }
    }
    
    return null;
  }

  return DSHangModel(
    uid: getValue('uid'),
    sku: getValue('sku'),
    counter: getValue('counter') != null ? int.tryParse(getValue('counter').toString()) : null,
    maNhapKho: getValue('maNhapKho'),
    tenModel: getValue('tenModel'),
    tenSanPham: getValue('tenSanPham'),
    sanPhamGoc: getValue('sanPhamGoc'),
    phanLoai1: getValue('phanLoai1'),
    congDung: getValue('congDung'),
    chatLieu: getValue('chatLieu'),
    mauSac: getValue('mauSac'),
    kichThuoc: getValue('kichThuoc'),
    dungTich: getValue('dungTich'),
    khoiLuong: getValue('khoiLuong'),
    quyCachDongGoi: getValue('quyCachDongGoi'),
    soLuongDongGoi: getValue('soLuongDongGoi'),
    donVi: getValue('donVi'),
    kichThuocDongGoi: getValue('kichThuocDongGoi'),
    thuongHieu: getValue('thuongHieu'),
    nhaCungCap: getValue('nhaCungCap'),
    xuatXu: getValue('xuatXu'),
    moTa: getValue('moTa'),
    hinhAnh: getValue('hinhAnh'),
    hangTieuHao: [1, '1', true, 'true'].contains(getValue('hangTieuHao')),
    coThoiHan: [1, '1', true, 'true'].contains(getValue('coThoiHan')),
    thoiHanSuDung: getValue('thoiHanSuDung'),
  );
}
}

class GiaoDichKhoModel {
  final String? giaoDichID;
  final String? ngay;
  final String? gio;
  final String? nguoiDung;
  final String? trangThai;
  final String? loaiGiaoDich;
  final String? maGiaoDich;
  final String? loHangID;
  final double? soLuong;
  final String? ghiChu;
  final double? thucTe;

  GiaoDichKhoModel({
    this.giaoDichID,
    this.ngay,
    this.gio,
    this.nguoiDung,
    this.trangThai,
    this.loaiGiaoDich,
    this.maGiaoDich,
    this.loHangID,
    this.soLuong,
    this.ghiChu,
    this.thucTe,
  });

  Map<String, dynamic> toMap() => {
    'giaoDichID': giaoDichID,
    'ngay': ngay,
    'gio': gio,
    'nguoiDung': nguoiDung,
    'trangThai': trangThai,
    'loaiGiaoDich': loaiGiaoDich,
    'maGiaoDich': maGiaoDich,
    'loHangID': loHangID,
    'soLuong': soLuong,
    'ghiChu': ghiChu,
    'thucTe': thucTe,
  };

  factory GiaoDichKhoModel.fromMap(Map<String, dynamic> map) {
    return GiaoDichKhoModel(
      giaoDichID: map['giaoDichID'],
      ngay: map['ngay'],
      gio: map['gio'],
      nguoiDung: map['nguoiDung'],
      trangThai: map['trangThai'],
      loaiGiaoDich: map['loaiGiaoDich'],
      maGiaoDich: map['maGiaoDich'],
      loHangID: map['loHangID'],
      soLuong: map['soLuong'] != null ? double.tryParse(map['soLuong'].toString()) : null,
      ghiChu: map['ghiChu'],
      thucTe: map['thucTe'] != null ? double.tryParse(map['thucTe'].toString()) : null,
    );
  }
}

class GiaoHangModel {
  final String? uid;
  final String? soPhieu;
  final String? nguoiGiao;
  final String? ngay;
  final String? gio;
  final String? ghiChu;
  final String? hinhAnh;
  final String? hinhAnh2;
  final String? dinhVi;

  GiaoHangModel({
    this.uid,
    this.soPhieu,
    this.nguoiGiao,
    this.ngay,
    this.gio,
    this.ghiChu,
    this.hinhAnh,
    this.hinhAnh2,
    this.dinhVi,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'soPhieu': soPhieu,
    'nguoiGiao': nguoiGiao,
    'ngay': ngay,
    'gio': gio,
    'ghiChu': ghiChu,
    'hinhAnh': hinhAnh,
    'hinhAnh2': hinhAnh2,
    'dinhVi': dinhVi,
  };

  factory GiaoHangModel.fromMap(Map<String, dynamic> map) {
    return GiaoHangModel(
      uid: map['uid'],
      soPhieu: map['soPhieu'],
      nguoiGiao: map['nguoiGiao'],
      ngay: map['ngay'],
      gio: map['gio'],
      ghiChu: map['ghiChu'],
      hinhAnh: map['hinhAnh'],
      hinhAnh2: map['hinhAnh2'],
      dinhVi: map['dinhVi'],
    );
  }
}

class KhoModel {
  final String? khoHangID;
  final String? tenKho;
  final String? diaChi;

  KhoModel({
    this.khoHangID,
    this.tenKho,
    this.diaChi,
  });

  Map<String, dynamic> toMap() => {
    'khoHangID': khoHangID,
    'tenKho': tenKho,
    'diaChi': diaChi,
  };

  factory KhoModel.fromMap(Map<String, dynamic> map) {
    return KhoModel(
      khoHangID: map['khoHangID'],
      tenKho: map['tenKho'],
      diaChi: map['diaChi'],
    );
  }
}

class KhuVucKhoModel {
  final String? khuVucKhoID;
  final String? khoHangID;

  KhuVucKhoModel({
    this.khuVucKhoID,
    this.khoHangID,
  });

  Map<String, dynamic> toMap() => {
    'khuVucKhoID': khuVucKhoID,
    'khoHangID': khoHangID,
  };

  factory KhuVucKhoModel.fromMap(Map<String, dynamic> map) {
    return KhuVucKhoModel(
      khuVucKhoID: map['khuVucKhoID'],
      khoHangID: map['khoHangID'],
    );
  }
}

class LoHangModel {
  final String? loHangID;
  final double? soLuongBanDau;
  final double? soLuongHienTai;
  final String? ngayNhap;
  final String? ngayCapNhat;
  final int? hanSuDung;
  final String? trangThai;
  final String? maHangID;
  final String? khoHangID;
  final String? khuVucKhoID;

  LoHangModel({
    this.loHangID,
    this.soLuongBanDau,
    this.soLuongHienTai,
    this.ngayNhap,
    this.ngayCapNhat,
    this.hanSuDung,
    this.trangThai,
    this.maHangID,
    this.khoHangID,
    this.khuVucKhoID,
  });

  Map<String, dynamic> toMap() => {
    'loHangID': loHangID,
    'soLuongBanDau': soLuongBanDau,
    'soLuongHienTai': soLuongHienTai,
    'ngayNhap': ngayNhap,
    'ngayCapNhat': ngayCapNhat,
    'hanSuDung': hanSuDung,
    'trangThai': trangThai,
    'maHangID': maHangID,
    'khoHangID': khoHangID,
    'khuVucKhoID': khuVucKhoID,
  };

  factory LoHangModel.fromMap(Map<String, dynamic> map) {
    return LoHangModel(
      loHangID: map['loHangID'],
      soLuongBanDau: map['soLuongBanDau'] != null ? double.tryParse(map['soLuongBanDau'].toString()) : null,
      soLuongHienTai: map['soLuongHienTai'] != null ? double.tryParse(map['soLuongHienTai'].toString()) : null,
      ngayNhap: map['ngayNhap'],
      ngayCapNhat: map['ngayCapNhat'],
      hanSuDung: map['hanSuDung'] != null ? int.tryParse(map['hanSuDung'].toString()) : null,
      trangThai: map['trangThai'],
      maHangID: map['maHangID'],
      khoHangID: map['khoHangID'],
      khuVucKhoID: map['khuVucKhoID'],
    );
  }
}

class TonKhoModel {
  final String? tonKhoID;
  final String? maHangID;
  final String? khoHangID;
  final double? soLuongHienTai;
  final double? soLuongDuTru;
  final double? soLuongCanXuat;

  TonKhoModel({
    this.tonKhoID,
    this.maHangID,
    this.khoHangID,
    this.soLuongHienTai,
    this.soLuongDuTru,
    this.soLuongCanXuat,
  });

  Map<String, dynamic> toMap() => {
    'tonKhoID': tonKhoID,
    'maHangID': maHangID,
    'khoHangID': khoHangID,
    'soLuongHienTai': soLuongHienTai,
    'soLuongDuTru': soLuongDuTru,
    'soLuongCanXuat': soLuongCanXuat,
  };

  factory TonKhoModel.fromMap(Map<String, dynamic> map) {
    return TonKhoModel(
      tonKhoID: map['tonKhoID'],
      maHangID: map['maHangID'],
      khoHangID: map['khoHangID'],
      soLuongHienTai: map['soLuongHienTai'] != null ? double.tryParse(map['soLuongHienTai'].toString()) : null,
      soLuongDuTru: map['soLuongDuTru'] != null ? double.tryParse(map['soLuongDuTru'].toString()) : null,
      soLuongCanXuat: map['soLuongCanXuat'] != null ? double.tryParse(map['soLuongCanXuat'].toString()) : null,
    );
  }
}

class NewsActivityModel {
  final String? likeID;
  final String? newsID;
  final String? ngay;
  final String? gio;
  final String? phanLoai;
  final String? noiDung;
  final String? nguoiDung;

  NewsActivityModel({
    this.likeID,
    this.newsID,
    this.ngay,
    this.gio,
    this.phanLoai,
    this.noiDung,
    this.nguoiDung,
  });

  Map<String, dynamic> toMap() => {
    'likeID': likeID,
    'newsID': newsID,
    'ngay': ngay,
    'gio': gio,
    'phanLoai': phanLoai,
    'noiDung': noiDung,
    'nguoiDung': nguoiDung,
  };

  factory NewsActivityModel.fromMap(Map<String, dynamic> map) {
    return NewsActivityModel(
      likeID: map['likeID'],
      newsID: map['newsID'],
      ngay: map['ngay'],
      gio: map['gio'],
      phanLoai: map['phanLoai'],
      noiDung: map['noiDung'],
      nguoiDung: map['nguoiDung'],
    );
  }
}

class NewsModel {
  final String? newsID;
  final String? tieuDe;
  final String? socialURL;
  final String? hinhAnh;
  final String? baiViet;
  final String? ngay;
  final String? logo;
  final String? tomTat;
  final String? tacGia;
  final int? likeCount;
  final int? commentCount;

  NewsModel({
    this.newsID,
    this.tieuDe,
    this.socialURL,
    this.hinhAnh,
    this.baiViet,
    this.ngay,
    this.logo,
    this.tomTat,
    this.tacGia,
    this.likeCount,
    this.commentCount,
  });

  Map<String, dynamic> toMap() => {
    'newsID': newsID,
    'tieuDe': tieuDe,
    'socialURL': socialURL,
    'hinhAnh': hinhAnh,
    'baiViet': baiViet,
    'ngay': ngay,
    'logo': logo,
    'tomTat': tomTat,
    'tacGia': tacGia,
    'likeCount': likeCount,
    'commentCount': commentCount,
  };

  factory NewsModel.fromMap(Map<String, dynamic> map) {
    return NewsModel(
      newsID: map['newsID'],
      tieuDe: map['tieuDe'],
      socialURL: map['socialURL'],
      hinhAnh: map['hinhAnh'],
      baiViet: map['baiViet'],
      ngay: map['ngay'],
      logo: map['logo'],
      tomTat: map['tomTat'],
      tacGia: map['tacGia'],
      likeCount: map['likeCount'] != null ? int.tryParse(map['likeCount'].toString()) : null,
      commentCount: map['commentCount'] != null ? int.tryParse(map['commentCount'].toString()) : null,
    );
  }
}
// Database Tables
class DatabaseTables {
  // Table Names
  static const String staffbioTable = 'staffbio';
  static const String checklistTable = 'checklist';
  static const String taskHistoryTable = 'taskhistory';
  static const String vtHistoryTable = 'vthistory';
  static const String staffListTable = 'stafflist';
  static const String positionListTable = 'positionlist';
  static const String projectListTable = 'projectlist';
  static const String baocaoTable = 'baocao';
  static const String dongPhucTable = 'dongphuc';
  static const String chiTietDPTable = 'chitietdp';
  static const String interactionTable = 'interaction';
  static const String orderMatHangTable = 'ordermathang';
  static const String orderTable = 'orders';
  static const String orderChiTietTable = 'orderchitiet';
  static const String orderDinhMucTable = 'orderdinhmuc';
  static const String chamCongCNTable = 'chamcongcn';
  static const String hinhAnhZaloTable = 'hinhanhzalo';
 static const String hdChiTietYCMMTable = 'HDChiTietYCMM';
 static const String hdDuTruTable = 'HDDuTru';
 static const String hdYeuCauMMTable = 'HDYeuCauMM';
  static const String chamCongTable = 'ChamCong';
 static const String chamCongGioTable = 'ChamCongGio';
 static const String chamCongLSTable = 'ChamCongLS';
 static const String chamCongCNThangTable = 'ChamCongCNThang';
   static const String chamCongVangNghiTcaTable = 'ChamCongVangNghiTca';
     static const String mapListTable = 'Map_List';
  static const String mapFloorTable = 'Map_Floor';
  static const String mapZoneTable = 'Map_Zone';
  static const String coinTable = 'Coin';
  static const String coinRateTable = 'CoinRate';
    static const String mapStaffTable = 'Map_Staff';
  static const String mapPositionTable = 'Map_Position';
      static const String donHangTable = 'donhang';
  static const String chiTietDonTable = 'chitietdon';
  static const String dsHangTable = 'dshang';
  static const String giaoDichKhoTable = 'giaodikhkho';
  static const String giaoHangTable = 'giaohang';
  static const String khoTable = 'kho';
  static const String khuVucKhoTable = 'khuvuckho';
  static const String loHangTable = 'lohang';
  static const String tonKhoTable = 'tonkho';
  static const String newsActivityTable = 'newsactivity';
  static const String newsTable = 'news';
  static const String createDSHangTable = '''
    CREATE TABLE $dsHangTable (
      uid TEXT,
      sku VARCHAR(100),
      Counter INT,
      MaNhapKho TEXT,
      TenModel VARCHAR(100),
      TenSanPham TEXT,
      SanPhamGoc TEXT,
      PhanLoai1 VARCHAR(100),
      CongDung TEXT,
      ChatLieu VARCHAR(100),
      MauSac VARCHAR(50),
      KichThuoc VARCHAR(100),
      DungTich VARCHAR(50),
      KhoiLuong VARCHAR(50),
      QuyCachDongGoi TEXT,
      SoLuongDongGoi TEXT,
      DonVi VARCHAR(50),
      KichThuocDongGoi VARCHAR(100),
      ThuongHieu VARCHAR(100),
      NhaCungCap VARCHAR(150),
      XuatXu VARCHAR(100),
      MoTa TEXT,
      HinhAnh VARCHAR(255),
      HangTieuHao TINYINT(1),
      CoThoiHan TINYINT(1),
      ThoiHanSuDung VARCHAR(50)
    )
  ''';
  
  static const String createGiaoDichKhoTable = '''
    CREATE TABLE $giaoDichKhoTable (
      giaoDichID TEXT,
      ngay DATE,
      gio TIME,
      nguoiDung VARCHAR(100),
      trangThai VARCHAR(100),
      loaiGiaoDich VARCHAR(100),
      maGiaoDich VARCHAR(100),
      loHangID TEXT,
      soLuong FLOAT,
      ghiChu TEXT,
      thucTe FLOAT
    )
  ''';
  
  static const String createGiaoHangTable = '''
    CREATE TABLE $giaoHangTable (
      UID VARCHAR(100),
      SoPhieu VARCHAR(100),
      NguoiGiao VARCHAR(100),
      Ngay DATE,
      Gio TIME,
      GhiChu TEXT,
      HinhAnh TEXT,
      HinhAnh2 TEXT,
      DinhVi VARCHAR(100)
    )
  ''';
  
  static const String createKhoTable = '''
    CREATE TABLE $khoTable (
      khoHangID TEXT,
      tenKho TEXT,
      diaChi TEXT
    )
  ''';
  
  static const String createKhuVucKhoTable = '''
    CREATE TABLE $khuVucKhoTable (
      khuVucKhoID TEXT,
      khoHangID TEXT
    )
  ''';
  
  static const String createLoHangTable = '''
    CREATE TABLE $loHangTable (
      loHangID TEXT,
      soLuongBanDau FLOAT,
      soLuongHienTai FLOAT,
      ngayNhap DATE,
      ngayCapNhat TIMESTAMP,
      hanSuDung INT,
      trangThai VARCHAR(100),
      maHangID TEXT,
      khoHangID TEXT,
      khuVucKhoID
    )
  ''';
  
  static const String createTonKhoTable = '''
    CREATE TABLE $tonKhoTable (
      tonKhoID TEXT,
      maHangID TEXT,
      khoHangID TEXT,
      soLuongHienTai FLOAT,
      soLuongDuTru FLOAT,
      soLuongCanXuat FLOAT
    )
  ''';
  
  static const String createNewsActivityTable = '''
    CREATE TABLE $newsActivityTable (
      LikeID VARCHAR(100),
      NewsID VARCHAR(100),
      Ngay DATE,
      Gio TIME,
      PhanLoai VARCHAR(100),
      NoiDung TEXT,
      NguoiDung VARCHAR(100)
    )
  ''';
  
  static const String createNewsTable = '''
    CREATE TABLE $newsTable (
      NewsID VARCHAR(100),
      TieuDe TEXT,
      SocialURL TEXT,
      HinhAnh TEXT,
      BaiViet TEXT,
      Ngay DATE,
      Logo TEXT,
      TomTat TEXT,
      TacGia VARCHAR(100),
      LikeCount INT,
      CommentCount INT
    )
  ''';

  static const String createDonHangTable = '''
    CREATE TABLE $donHangTable (
      soPhieu VARCHAR(255) NOT NULL PRIMARY KEY,
      nguoiTao VARCHAR(255),
      ngay DATE,
      tenKhachHang TEXT,
      sdtKhachHang VARCHAR(255),
      soPO VARCHAR(255),
      diaChi TEXT,
      mst VARCHAR(255),
      tapKH VARCHAR(255),
      tenNguoiGiaoDich VARCHAR(255),
      boPhanGiaoDich VARCHAR(255),
      sdtNguoiGiaoDich VARCHAR(255),
      thoiGianDatHang VARCHAR(255),
      ngayYeuCauGiao DATE,
      thoiGianCapNhatTrangThai DATETIME,
      phuongThucThanhToan VARCHAR(255),
      thanhToanSauNhanHangXNgay INT,
      datCocSauXNgay INT,
      giayToCanKhiGiaoHang TEXT,
      thoiGianVietHoaDon TEXT,
      thongTinVietHoaDon TEXT,
      diaChiGiaoHang TEXT,
      hoTenNguoiNhanHoaHong VARCHAR(255),
      sdtNguoiNhanHoaHong VARCHAR(255),
      hinhThucChuyenHoaHong VARCHAR(255),
      thongTinNhanHoaHong VARCHAR(255),
      ngaySeGiao TEXT,
      thoiGianCapNhatMoiNhat DATETIME,
      phuongThucGiaoHang VARCHAR(255),
      phuongTienGiaoHang VARCHAR(255),
      hoTenNguoiGiaoHang VARCHAR(255),
      ghiChu TEXT,
      giaNet INT,
      tongTien INT,
      vat10 INT,
      tongCong INT,
      hoaHong10 INT,
      tienGui10 INT,
      thueTNDN INT,
      vanChuyen INT,
      thucThu INT,
      nguoiNhanHang VARCHAR(255),
      sdtNguoiNhanHang VARCHAR(255),
      phieuXuatKho VARCHAR(255),
      trangThai VARCHAR(255),
      tenKhachHang2 TEXT
    )
  ''';
  static const String createChiTietDonTable = '''
    CREATE TABLE $chiTietDonTable (
      uid VARCHAR(255) NOT NULL PRIMARY KEY,
      soPhieu VARCHAR(255),
      trangThai VARCHAR(255),
      tenHang TEXT,
      maHang TEXT,
      donViTinh VARCHAR(255),
      soLuongYeuCau FLOAT,
      donGia INT,
      thanhTien INT,
      soLuongThucGiao FLOAT,
      chiNhanh VARCHAR(255),
      idHang TEXT,
      soLuongKhachNhan FLOAT,
      duyet VARCHAR(255),
      xuatXuHangKhac TEXT,
      baoGia VARCHAR(255),
      hinhAnh VARCHAR(255),
      ghiChu VARCHAR(255),
      phanTramVAT INT,
      vat INT,
      tenKhachHang TEXT,
      updateTime DATETIME,
      FOREIGN KEY (soPhieu) REFERENCES $donHangTable(soPhieu)
    )
  ''';
  static const String createMapStaffTable = '''
    CREATE TABLE $mapStaffTable (
      uid VARCHAR(100),
      mapProject VARCHAR(200),
      nguoiDung VARCHAR(100),
      hoTen VARCHAR(200),
      vaiTro VARCHAR(200)
    )
  ''';
  
  static const String createMapPositionTable = '''
    CREATE TABLE $mapPositionTable (
      uid VARCHAR(100),
      mapList VARCHAR(200),
      mapFloor VARCHAR(200),
      mapZone VARCHAR(200),
      viTri VARCHAR(200)
    )
  ''';
  static const String createCoinTable = '''
    CREATE TABLE $coinTable (
      uid VARCHAR(100),
      nguoiDung VARCHAR(100),
      ngay DATE,
      soLuong INT,
      tongTien INT
    )
  ''';
  
  static const String createCoinRateTable = '''
    CREATE TABLE $coinRateTable (
      uid VARCHAR(100),
      caseType VARCHAR(100),
      startRate INT,
      endRate INT,
      maxCount INT
    )
  ''';

  static const String createMapListTable = '''
    CREATE TABLE $mapListTable (
      mapUID VARCHAR(255) PRIMARY KEY,
      nguoiDung VARCHAR(255),
      boPhan TEXT,
      tenBanDo TEXT,
      hinhAnhBanDo TEXT,
      chieuDaiMet FLOAT,
      chieuCaoMet FLOAT
    )
  ''';
  
  static const String createMapFloorTable = '''
    CREATE TABLE $mapFloorTable (
      floorUID VARCHAR(255) PRIMARY KEY,
      mapUID VARCHAR(255),
      tenTang TEXT,
      hinhAnhTang TEXT,
      chieuDaiMet FLOAT,
      chieuCaoMet FLOAT,
      offsetX FLOAT,
      offsetY FLOAT,
      FOREIGN KEY (mapUID) REFERENCES $mapListTable(mapUID)
    )
  ''';
  
  static const String createMapZoneTable = '''
    CREATE TABLE $mapZoneTable (
      zoneUID VARCHAR(255) PRIMARY KEY,
      floorUID VARCHAR(255),
      tenKhuVuc TEXT,
      cacDiemMoc TEXT,
      mauSac VARCHAR(255),
      FOREIGN KEY (floorUID) REFERENCES $mapFloorTable(floorUID)
    )
  ''';
 static const String createChamCongVangNghiTcaTable = '''
    CREATE TABLE $chamCongVangNghiTcaTable (
      UID varchar(100),
      NguoiDung varchar(100),
      PhanLoai varchar(100),
      NgayBatDau date,
      NgayKetThuc date,
      GhiChu text,
      TruongHop varchar(100),
      NguoiDuyet varchar(100),
      TrangThai varchar(100),
      GiaTriNgay decimal(10,2)
    )
  ''';
static const String createChamCongCNThangTable = '''
  CREATE TABLE $chamCongCNThangTable (
    UID varchar(100),
    NgayCapNhat date,
    GiaiDoan date,
    MaNV varchar(100),
    BoPhan text,
    MaBP text,
    PhanLoaiDacBiet varchar(100),
    GhiChu text,
    CongChuanToiDa int,
    XepLoaiTuDong varchar(100),
    Tuan_1va2 decimal(10,0),
    Phep_1va2 decimal(10,0),
    HT_1va2 decimal(10,0),
    Tuan_3va4 decimal(10,0),
    Phep_3va4 decimal(10,0),
    HT_3va4 decimal(10,0),
    Tong_Cong decimal(10,0),
    Tong_Phep decimal(10,0),
    Tong_Le decimal(10,0),
    Tong_NgoaiGio decimal(10,0),
    Tong_HV decimal(10,0),
    Tong_Dem decimal(10,0),
    Tong_CD decimal(10,0),
    Tong_HT decimal(10,0),
    TongLuong int,
    UngLan1 int,
    UngLan2 int,
    ThanhToan3 int,
    TruyLinh int,
    TruyThu int,
    Khac int,
    MucLuongThang int,
    MucLuongNgoaiGio int,
    MucLuongNgoaiGio2 int
  )
''';
 static const String createChamCongTable = '''
    CREATE TABLE $chamCongTable (
      NguoiDung varchar(100),
      PhanLoai varchar(100),
      TenGoi varchar(100),
      DinhVi varchar(100)
    )
  ''';

  static const String createChamCongGioTable = '''
    CREATE TABLE $chamCongGioTable (
      NguoiDung varchar(100),
      PhanLoai varchar(100),
      GioBatDau time,
      GioKetThuc time,
      SoCong decimal(10,2),
      SoPhut int
    )
  ''';

  static const String createChamCongLSTable = '''
    CREATE TABLE $chamCongLSTable (
      UID varchar(100),
      NguoiDung varchar(100),
      Ngay date,
      BatDau time,
      PhanLoaiBatDau varchar(100),
      DiemChamBatDau varchar(100),
      DinhViBatDau varchar(100),
      KhoangCachBatDau decimal(10,0),
      HopLeBatDau varchar(100),
      HinhAnhBatDau text,
      TrangThaiBatDau varchar(100),
      NguoiDuyetBatDau varchar(100),
      GioLamBatDau time,
      DiMuonBatDau decimal(10,0),
      KetThuc time,
      PhanLoaiKetThuc varchar(100),
      DiemChamKetThuc varchar(100),
      DinhViKetThuc varchar(100),
      KhoangCachKetThuc decimal(10,0),
      HopLeKetThuc varchar(100),
      HinhAnhKetThuc text,
      TrangThaiKetThuc varchar(100),
      NguoiDuyetKetThuc varchar(100),
      GioLamKetThuc time,
      DiMuonKetThuc decimal(10,0),
      Ngay2 date,
      TongDiMuonNgay decimal(10,0),
      TongCongNgay decimal(10,0)
    )
  ''';
static const String createHDChiTietYCMMTable = '''
   CREATE TABLE $hdChiTietYCMMTable (
     UID varchar(100),
     SoPhieuID varchar(100),
     `Phân Loại` text,
     `Danh Mục` text,
     `Mã` text,
     TenVTMMTB text,
     DonVi varchar(100),
     SoLuong int,
     LoaiTien varchar(100),
     DonGia int,
     ThanhTien int,
     GhiChu text,
     KhuVucThucHien text,
     DienTichSuDung text,
     TanSuat text
   )
 ''';

 static const String createHDDuTruTable = '''
   CREATE TABLE $hdDuTruTable (
     SoPhieuID varchar(100),
     NguoiDung varchar(100),
     NhanVienPhoiHop varchar(100),
     ChiaSe text,
     PhanLoai varchar(100),
     BoPhan text,
     DiaChi text,
     SoCongNhan decimal(10,0),
     SoGiamSat decimal(10,0),
     LoaiHopDong text,
     ThoiGianDuKien date,
     KhuVucThucHien text,
     TrangThai varchar(100),
     NgayTao date,
     NgayCapNhat date
   )
 ''';

 static const String createHDYeuCauMMTable = '''
   CREATE TABLE $hdYeuCauMMTable (
     SoPhieuUID varchar(100),
     DuTruID varchar(100),
     Ngaytao date,
     NgayGui date,
     NguoiDung varchar(100),
     NhanVienPhoiHop varchar(100),
     BoPhan text,
     DiaChi text,
     PhanLoai varchar(100),
     TrangThai varchar(100),
     ChuKyNguoiTao text,
     NguoiXuLy text,
     ChuKyNguoiXuLy text,
     NguoiDuyet text,
     ChuKyNguoiDuyet text,
     NguoiDuyet2 text,
     ChuKyNguoiDuyet2 text,
     StatusUpdate text
   )
 ''';
static const String createHinhAnhZaloTable = '''
  CREATE TABLE $hinhAnhZaloTable (
    UID VARCHAR(100),
    Ngay DATE,
    Gio TIME,
    BoPhan TEXT,
    GiamSat TEXT,
    NguoiDung TEXT,
    HinhAnh TEXT,
    KhuVuc TEXT,
    QuanTrong TEXT,
    PRIMARY KEY (UID)
  )
''';
// Order table
static const String createOrderTable = '''
  CREATE TABLE $orderTable (
    OrderID VARCHAR(100),
    Ngay DATE,
    TenDon TEXT,
    BoPhan TEXT,
    NguoiDung VARCHAR(100),
    TrangThai VARCHAR(100),
    GhiChu VARCHAR(100),
    DinhMuc INT,
    NguoiDuyet VARCHAR(100),
    TongTien INT,
    PhanLoai VARCHAR(100),
    NgayCapNhat DATE,
    VanDe TEXT,
    HinhAnh TEXT,
    PRIMARY KEY (OrderID)
  )
''';

// OrderDinhMuc table
static const String createOrderDinhMucTable = '''
  CREATE TABLE $orderDinhMucTable (
    BoPhan TEXT,
    ThangDat VARCHAR(100),
    NguoiDuyet VARCHAR(100),
    NguoiDung VARCHAR(100),
    MaKho TEXT,
    TanSuat INT,
    GhiChu TEXT,
    SoCongNhan DECIMAL(10,0),
    DinhMucTCN INT,
    CongTruKhac INT,
    DinhMuc INT,
    PRIMARY KEY (BoPhan, ThangDat)
  )
''';

// OrderChiTiet table
static const String createOrderChiTietTable = '''
  CREATE TABLE $orderChiTietTable (
    UID VARCHAR(100),
    OrderID VARCHAR(100),
    ItemID VARCHAR(100),
    Ten TEXT,
    PhanLoai VARCHAR(100),
    GhiChu VARCHAR(100),
    DonVi VARCHAR(100),
    SoLuong DECIMAL(10,0),
    DonGia INT,
    KhachTra BOOLEAN,
    ThanhTien INT,
    PRIMARY KEY (UID)
  )
''';

// ChamCongCN table
static const String createChamCongCNTable = '''
  CREATE TABLE $chamCongCNTable (
    UID VARCHAR(100),
    Ngay DATE,
    Gio TIME,
    NguoiDung TEXT,
    BoPhan TEXT,
    MaBP VARCHAR(100),
    PhanLoai VARCHAR(100),
    MaNV VARCHAR(100),
    CongThuongChu VARCHAR(100),
    NgoaiGioThuong DECIMAL(10,0),
    NgoaiGioKhac DECIMAL(10,0),
    NgoaiGiox15 DECIMAL(10,0),
    NgoaiGiox2 DECIMAL(10,0),
    HoTro INT,
    PartTime INT,
    PartTimeSang INT,
    PartTimeChieu INT,
    CongLe DECIMAL(10,0),
    PRIMARY KEY (UID)
  )
''';
  static const String createOrderMatHangTable = '''
  CREATE TABLE $orderMatHangTable (
    ItemId VARCHAR(100),
    Ten TEXT,
    DonVi VARCHAR(100),
    DonGia INT,
    PhanLoai VARCHAR(100),
    PhanNhom VARCHAR(100),
    HinhAnh TEXT,
    PRIMARY KEY (ItemId)
  )
''';
static const String createDongPhucTable = '''
  CREATE TABLE $dongPhucTable (
    UID VARCHAR(100),
    NguoiDung VARCHAR(100),
    BoPhan TEXT,
    PhanLoai VARCHAR(100),
    ThoiGianNhan DATE,
    TrangThai VARCHAR(100),
    Thang DATE,
    XuLy VARCHAR(100),
    PRIMARY KEY (UID)
  )
''';
static const String createInteractionTable = '''
  CREATE TABLE $interactionTable (
    UID varchar(100),
    Ngay DATE,
    Gio TIME,
    NguoiDung varchar(100),
    BoPhan text,
    GiamSat varchar(100),
    NoiDung text,
    ChuDe varchar(100),
    PhanLoai varchar(100),
    PRIMARY KEY (UID)
  )
''';
static const String createChiTietDPTable = '''
  CREATE TABLE $chiTietDPTable (
    UID VARCHAR(100) PRIMARY KEY,
    OrderUID VARCHAR(100),
    ThoiGianGanNhat DATE,
    MaCN VARCHAR(100),
    Ten TEXT,
    GioiTinh VARCHAR(100),
    LoaiAo TEXT,
    SizeAo TEXT,
    LoaiQuan TEXT,
    SizeQuan TEXT,
    LoaiGiay TEXT,
    SizeGiay TEXT,
    LoaiKhac TEXT,
    SizeKhac TEXT,
    GhiChu TEXT
  )
''';
  static const String createProjectListTable = '''
  CREATE TABLE $projectListTable (
    BoPhan text,
    MaBP varchar(100),
    PRIMARY KEY (MaBP)
  )
''';
static const String createBaocaoTable = '''
  CREATE TABLE $baocaoTable (
    UID VARCHAR(100),
    NguoiDung VARCHAR(100),
    Ngay DATE,
    Gio TIME,
    BoPhan TEXT,
    ChiaSe TEXT,
    PhanLoai VARCHAR(100),
    HinhAnh TEXT,
    MoTaChung TEXT,
    GiaiPhapChung TEXT,
    DanhGiaNS TEXT,
    GiaiPhapNS TEXT,
    DanhGiaCL TEXT,
    GiaiPhapCL TEXT,
    DanhGiaVT TEXT,
    GiaiPhapVT TEXT,
    DanhGiaYKienKhachHang TEXT,
    GiaiPhapYKienKhachHang TEXT,
    DanhGiaMayMoc TEXT,
    GiaiPhapMayMoc TEXT,
    Nhom TEXT,
    PhatSinh TEXT,
    XetDuyet TEXT
  )
''';
  // Create Table Statements
  static const String createStaffbioTable = '''
  CREATE TABLE $staffbioTable (
    UID VARCHAR PRIMARY KEY,
    VungMien VARCHAR,
    LoaiNV VARCHAR,
    MaNV VARCHAR,
    Ho_ten VARCHAR,
    Ngay_vao DATE,
    Thang_vao DATE,
    So_thang INT,
    Loai_hinh_lao_dong VARCHAR,
    Chuc_vu VARCHAR,
    Gioi_tinh VARCHAR,
    Ngay_sinh DATE,
    Tuoi INT,
    Can_cuoc_cong_dan VARCHAR,
    Ngay_cap DATE,
    Noi_cap VARCHAR,
    Nguyen_quan TEXT,
    Thuong_tru TEXT,
    Dia_chi_lien_lac TEXT,
    Ma_so_thue VARCHAR,
    CMND_cu VARCHAR,
    ngay_cap_cu VARCHAR,
    Noi_cap_cu VARCHAR,
    Nguyen_quan_cu VARCHAR,
    Dia_chi_thuong_tru_cu TEXT,
    MST_ghi_chu VARCHAR,
    Dan_toc VARCHAR,
    SDT VARCHAR,
    SDT2 VARCHAR,
    Email VARCHAR,
    Dia_chinh_cap4 VARCHAR,
    Dia_chinh_cap3 VARCHAR,
    Dia_chinh_cap2 VARCHAR,
    Dia_chinh_cap1 VARCHAR,
    Don_vi VARCHAR,
    Giam_sat VARCHAR,
    So_tai_khoan VARCHAR,
    Ngan_hang VARCHAR,
    MST_thu_nhap_ca_nhan VARCHAR,
    So_BHXH VARCHAR,
    Bat_dau_tham_gia_BHXH VARCHAR,
    Ket_thuc_BHXH VARCHAR,
    Ghi_chu TEXT,
    Tinh_trang VARCHAR,
    Ngay_nghi DATE,
    Tinh_trang_ho_so VARCHAR,
    Ho_so_con_thieu VARCHAR,
    Qua_trinh TEXT,
    Partime VARCHAR,
    Nguoi_gioi_thieu VARCHAR,
    Nguon_tuyen_dung VARCHAR,
    CTV_30k VARCHAR,
    Doanh_so_tuyen_dung VARCHAR,
    Trinh_do VARCHAR,
    Chuyen_nganh VARCHAR,
    PL_dac_biet VARCHAR,
    Lam_2noi VARCHAR,
    Loai_dt VARCHAR,
    So_the_BH_huu_tri VARCHAR,
    Tinh_trang_tiem_chung VARCHAR,
    Ngay_cap_giay_khamSK DATE,
    SDT_nhan_than VARCHAR,
    Ho_ten_bo VARCHAR,
    Nam_sinh_bo VARCHAR,
    Ho_ten_me VARCHAR,
    Nam_sinh_me VARCHAR,
    Ho_ten_vochong VARCHAR,
    Nam_sinh_vochong VARCHAR,
    Con VARCHAR,
    Nam_sinh_con VARCHAR,
    Chu_ho_khau VARCHAR,
    Nam_sinh_chu_ho VARCHAR,
    Quan_he_voi_chu_ho VARCHAR,
    Ho_so_thau VARCHAR,
    So_the_BHYT VARCHAR,
    ChieuCao REAL,
    CanNang REAL,
    NgayCapDP DATE
  );
''';
static const String createStaffListTable = '''
    CREATE TABLE $staffListTable (
      UID VARCHAR,
      MaNV VARCHAR,
      NguoiDung VARCHAR,
      VT VARCHAR,
      BoPhan VARCHAR,
      PRIMARY KEY (UID)
    )
  ''';

  static const String createPositionListTable = '''
    CREATE TABLE $positionListTable (
      UID VARCHAR,
      BoPhan VARCHAR,
      NguoiDung VARCHAR,
      VT VARCHAR,
      KhuVuc TEXT,
      Ca_batdau TIME,
      Ca_ketthuc TIME,
      PRIMARY KEY (UID)
    )
  ''';
  static const String createChecklistTable = '''
    CREATE TABLE $checklistTable (
      DUAN VARCHAR,
      VITRI VARCHAR,
      WEEKDAY VARCHAR,
      START TIME,
      END TIME,
      TASK TEXT,
      TUAN VARCHAR,
      THANG VARCHAR,
      NGAYBC DATE,
      TASKID VARCHAR,
      PRIMARY KEY (DUAN, VITRI, WEEKDAY, START, TASKID)
    )
  ''';
  
  static const String createTaskHistoryTable = '''
    CREATE TABLE $taskHistoryTable (
      UID VARCHAR,
      NguoiDung VARCHAR,
      TaskID VARCHAR,
      KetQua VARCHAR,
      Ngay DATE,
      Gio TIME,
      ChiTiet TEXT,
      ChiTiet2 TEXT,
      ViTri VARCHAR,
      BoPhan VARCHAR,
      PhanLoai VARCHAR,
      HinhAnh VARCHAR,
      GiaiPhap TEXT,
      PRIMARY KEY (UID)
    )
  ''';

  static const String createVTHistoryTable = '''
    CREATE TABLE $vtHistoryTable (
      UID VARCHAR,
      NguoiDung VARCHAR,
      Ngay DATE,
      Gio TIME,
      BoPhan VARCHAR,
      ViTri VARCHAR,
      NhanVien VARCHAR,
      TrangThai VARCHAR,
      HoTro VARCHAR,
      PhuongAn TEXT,
      PRIMARY KEY (UID, Ngay, Gio)
    )
  ''';
}