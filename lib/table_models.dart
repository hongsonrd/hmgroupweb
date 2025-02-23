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
    'KhachTra': khachTra,
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
    KhachTra TINYINT(1),
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