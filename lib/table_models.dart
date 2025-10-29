import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'multifile.dart';

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
  DonHangModel copyWith({
    String? soPhieu,
    String? nguoiTao,
    String? ngay,
    String? tenKhachHang,
    String? sdtKhachHang,
    String? soPO,
    String? diaChi,
    String? mst,
    String? tapKH,
    String? tenNguoiGiaoDich,
    String? boPhanGiaoDich,
    String? sdtNguoiGiaoDich,
    String? thoiGianDatHang,
    String? ngayYeuCauGiao,
    String? thoiGianCapNhatTrangThai,
    String? phuongThucThanhToan,
    int? thanhToanSauNhanHangXNgay,
    int? datCocSauXNgay,
    String? giayToCanKhiGiaoHang,
    String? thoiGianVietHoaDon,
    String? thongTinVietHoaDon,
    String? diaChiGiaoHang,
    String? hoTenNguoiNhanHoaHong,
    String? sdtNguoiNhanHoaHong,
    String? hinhThucChuyenHoaHong,
    String? thongTinNhanHoaHong,
    String? ngaySeGiao,
    String? thoiGianCapNhatMoiNhat,
    String? phuongThucGiaoHang,
    String? phuongTienGiaoHang,
    String? hoTenNguoiGiaoHang,
    String? ghiChu,
    int? giaNet,
    int? tongTien,
    int? vat10,
    int? tongCong,
    int? hoaHong10,
    int? tienGui10,
    int? thueTNDN,
    int? vanChuyen,
    int? thucThu,
    String? nguoiNhanHang,
    String? sdtNguoiNhanHang,
    String? phieuXuatKho,
    String? trangThai,
    String? tenKhachHang2,
  }) {
    return DonHangModel(
      soPhieu: soPhieu ?? this.soPhieu,
      nguoiTao: nguoiTao ?? this.nguoiTao,
      ngay: ngay ?? this.ngay,
      tenKhachHang: tenKhachHang ?? this.tenKhachHang,
      sdtKhachHang: sdtKhachHang ?? this.sdtKhachHang,
      soPO: soPO ?? this.soPO,
      diaChi: diaChi ?? this.diaChi,
      mst: mst ?? this.mst,
      tapKH: tapKH ?? this.tapKH,
      tenNguoiGiaoDich: tenNguoiGiaoDich ?? this.tenNguoiGiaoDich,
      boPhanGiaoDich: boPhanGiaoDich ?? this.boPhanGiaoDich,
      sdtNguoiGiaoDich: sdtNguoiGiaoDich ?? this.sdtNguoiGiaoDich,
      thoiGianDatHang: thoiGianDatHang ?? this.thoiGianDatHang,
      ngayYeuCauGiao: ngayYeuCauGiao ?? this.ngayYeuCauGiao,
      thoiGianCapNhatTrangThai: thoiGianCapNhatTrangThai ?? this.thoiGianCapNhatTrangThai,
      phuongThucThanhToan: phuongThucThanhToan ?? this.phuongThucThanhToan,
      thanhToanSauNhanHangXNgay: thanhToanSauNhanHangXNgay ?? this.thanhToanSauNhanHangXNgay,
      datCocSauXNgay: datCocSauXNgay ?? this.datCocSauXNgay,
      giayToCanKhiGiaoHang: giayToCanKhiGiaoHang ?? this.giayToCanKhiGiaoHang,
      thoiGianVietHoaDon: thoiGianVietHoaDon ?? this.thoiGianVietHoaDon,
      thongTinVietHoaDon: thongTinVietHoaDon ?? this.thongTinVietHoaDon,
      diaChiGiaoHang: diaChiGiaoHang ?? this.diaChiGiaoHang,
      hoTenNguoiNhanHoaHong: hoTenNguoiNhanHoaHong ?? this.hoTenNguoiNhanHoaHong,
      sdtNguoiNhanHoaHong: sdtNguoiNhanHoaHong ?? this.sdtNguoiNhanHoaHong,
      hinhThucChuyenHoaHong: hinhThucChuyenHoaHong ?? this.hinhThucChuyenHoaHong,
      thongTinNhanHoaHong: thongTinNhanHoaHong ?? this.thongTinNhanHoaHong,
      ngaySeGiao: ngaySeGiao ?? this.ngaySeGiao,
      thoiGianCapNhatMoiNhat: thoiGianCapNhatMoiNhat ?? this.thoiGianCapNhatMoiNhat,
      phuongThucGiaoHang: phuongThucGiaoHang ?? this.phuongThucGiaoHang,
      phuongTienGiaoHang: phuongTienGiaoHang ?? this.phuongTienGiaoHang,
      hoTenNguoiGiaoHang: hoTenNguoiGiaoHang ?? this.hoTenNguoiGiaoHang,
      ghiChu: ghiChu ?? this.ghiChu,
      giaNet: giaNet ?? this.giaNet,
      tongTien: tongTien ?? this.tongTien,
      vat10: vat10 ?? this.vat10,
      tongCong: tongCong ?? this.tongCong,
      hoaHong10: hoaHong10 ?? this.hoaHong10,
      tienGui10: tienGui10 ?? this.tienGui10,
      thueTNDN: thueTNDN ?? this.thueTNDN,
      vanChuyen: vanChuyen ?? this.vanChuyen,
      thucThu: thucThu ?? this.thucThu,
      nguoiNhanHang: nguoiNhanHang ?? this.nguoiNhanHang,
      sdtNguoiNhanHang: sdtNguoiNhanHang ?? this.sdtNguoiNhanHang,
      phieuXuatKho: phieuXuatKho ?? this.phieuXuatKho,
      trangThai: trangThai ?? this.trangThai,
      tenKhachHang2: tenKhachHang2 ?? this.tenKhachHang2,
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
    'HangTieuHao': hangTieuHao == true ? 1 : 0, 
    'CoThoiHan': coThoiHan == true ? 1 : 0,
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
class KhuVucKhoChiTietModel {
  final String? chiTietID;
  final String? khuVucKhoID;
  final String? tang;
  final String? tangSize;
  final String? phong;
  final String? ke;
  final String? tangKe;
  final String? gio;
  final String? noiDung;
  final String? viTri;
  int? dungTich;

  KhuVucKhoChiTietModel({
    this.chiTietID,
    this.khuVucKhoID,
    this.tang,
    this.tangSize,
    this.phong,
    this.ke,
    this.tangKe,
    this.gio,
    this.noiDung,
    this.viTri,
    this.dungTich,
  });

  Map<String, dynamic> toMap() => {
    'chiTietID': chiTietID,
    'khuVucKhoID': khuVucKhoID,
    'tang': tang,
    'tangSize': tangSize,
    'phong': phong,
    'ke': ke,
    'tangKe': tangKe,
    'gio': gio,
    'noiDung': noiDung,
    'viTri': viTri,
    'dungTich': dungTich,
  };

  factory KhuVucKhoChiTietModel.fromMap(Map<String, dynamic> map) {
    return KhuVucKhoChiTietModel(
      chiTietID: map['chiTietID'],
      khuVucKhoID: map['khuVucKhoID'],
      tang: map['tang'],
      tangSize: map['tangSize'],
      phong: map['phong'],
      ke: map['ke'],
      tangKe: map['tangKe'],
      gio: map['gio'],
      noiDung: map['noiDung'],
      viTri: map['viTri'],
      dungTich: map['dungTich'],
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
// Model for GoClean_CongViec table
class GoCleanCongViecModel {
  final String? lichLamViecID;
  final String? giaoViecID;
  final DateTime? ngay;
  final String? nguoiThucHien;
  final String? xacNhan;
  final String? qrCode;
  final String? mocBatDau; // Storing TIME as String, parse as needed
  final String? hinhAnhTruoc;
  final String? mocKetThuc; // Storing TIME as String, parse as needed
  final String? hinhAnhSau;
  final int? thucHienDanhGia;
  final String? moTaThucHien;
  final String? khachHang;
  final int? khachHangDanhGia;
  final String? thoiGianDanhGia; // Storing TIME as String, parse as needed
  final String? khachHangMoTa;
  final String? khachHangChupAnh;
  final String? trangThai;

  GoCleanCongViecModel({
    this.lichLamViecID,
    this.giaoViecID,
    this.ngay,
    this.nguoiThucHien,
    this.xacNhan,
    this.qrCode,
    this.mocBatDau,
    this.hinhAnhTruoc,
    this.mocKetThuc,
    this.hinhAnhSau,
    this.thucHienDanhGia,
    this.moTaThucHien,
    this.khachHang,
    this.khachHangDanhGia,
    this.thoiGianDanhGia,
    this.khachHangMoTa,
    this.khachHangChupAnh,
    this.trangThai,
  });

  Map<String, dynamic> toMap() => {
    'LichLamViecID': lichLamViecID,
    'GiaoViecID': giaoViecID,
    'Ngay': ngay?.toIso8601String().split('T').first, // Format as YYYY-MM-DD
    'NguoiThucHien': nguoiThucHien,
    'XacNhan': xacNhan,
    'QRcode': qrCode,
    'MocBatDau': mocBatDau,
    'HinhAnhTruoc': hinhAnhTruoc,
    'MocKetThuc': mocKetThuc,
    'HinhAnhSau': hinhAnhSau,
    'ThucHienDanhGia': thucHienDanhGia,
    'MoTaThucHien': moTaThucHien,
    'KhachHang': khachHang,
    'KhachHangDanhGia': khachHangDanhGia,
    'ThoiGianDanhGia': thoiGianDanhGia,
    'KhachHangMoTa': khachHangMoTa,
    'KhachHangChupAnh': khachHangChupAnh,
    'TrangThai': trangThai,
  };

  factory GoCleanCongViecModel.fromMap(Map<dynamic, dynamic> map) {
    return GoCleanCongViecModel(
      lichLamViecID: map['LichLamViecID']?.toString(),
      giaoViecID: map['GiaoViecID']?.toString(),
      ngay: map['Ngay'] != null ? DateTime.tryParse(map['Ngay'].toString()) : null,
      nguoiThucHien: map['NguoiThucHien']?.toString(),
      xacNhan: map['XacNhan']?.toString(),
      qrCode: map['QRcode']?.toString(),
      mocBatDau: map['MocBatDau']?.toString(),
      hinhAnhTruoc: map['HinhAnhTruoc']?.toString(),
      mocKetThuc: map['MocKetThuc']?.toString(),
      hinhAnhSau: map['HinhAnhSau']?.toString(),
      thucHienDanhGia: map['ThucHienDanhGia'] != null ? int.tryParse(map['ThucHienDanhGia'].toString()) : null,
      moTaThucHien: map['MoTaThucHien']?.toString(),
      khachHang: map['KhachHang']?.toString(),
      khachHangDanhGia: map['KhachHangDanhGia'] != null ? int.tryParse(map['KhachHangDanhGia'].toString()) : null,
      thoiGianDanhGia: map['ThoiGianDanhGia']?.toString(),
      khachHangMoTa: map['KhachHangMoTa']?.toString(),
      khachHangChupAnh: map['KhachHangChupAnh']?.toString(),
      trangThai: map['TrangThai']?.toString(),
    );
  }
}

// Model for GoClean_TaiKhoan table
class GoCleanTaiKhoanModel {
  final String? uid;
  final String? taiKhoan;
  final String? phanLoai;
  final String? dinhVi;
  final String? loaiDinhVi;
  final String? sdt;
  final String? email;
  final String? diaDiem;
  final String? diaChi;
  final String? hinhAnh;
  final String? trangThai;
  final String? nhom;
  final String? admin;

  GoCleanTaiKhoanModel({
    this.uid,
    this.taiKhoan,
    this.phanLoai,
    this.dinhVi,
    this.loaiDinhVi,
    this.sdt,
    this.email,
    this.diaDiem,
    this.diaChi,
    this.hinhAnh,
    this.trangThai,
    this.nhom,
    this.admin,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'TaiKhoan': taiKhoan,
    'PhanLoai': phanLoai,
    'DinhVi': dinhVi,
    'LoaiDinhVi': loaiDinhVi,
    'SDT': sdt,
    'Email': email,
    'DiaDiem': diaDiem,
    'DiaChi': diaChi,
    'HinhAnh': hinhAnh,
    'TrangThai': trangThai,
    'Nhom': nhom,
    'Admin': admin,
  };

  factory GoCleanTaiKhoanModel.fromMap(Map<dynamic, dynamic> map) {
    return GoCleanTaiKhoanModel(
      uid: map['UID']?.toString(),
      taiKhoan: map['TaiKhoan']?.toString(),
      phanLoai: map['PhanLoai']?.toString(),
      dinhVi: map['DinhVi']?.toString(),
      loaiDinhVi: map['LoaiDinhVi']?.toString(),
      sdt: map['SDT']?.toString(),
      email: map['Email']?.toString(),
      diaDiem: map['DiaDiem']?.toString(),
      diaChi: map['DiaChi']?.toString(),
      hinhAnh: map['HinhAnh']?.toString(),
      trangThai: map['TrangThai']?.toString(),
      nhom: map['Nhom']?.toString(),
      admin: map['Admin']?.toString(),
    );
  }
}

// Model for GoClean_YeuCau table
class GoCleanYeuCauModel {
  final String? giaoViecID;
  final String? nguoiTao;
  final String? nguoiNghiemThu;
  final String? diaDiem;
  final String? diaChi;
  final String? dinhVi;
  final String? lapLai;
  final DateTime? ngayBatDau;
  final DateTime? ngayKetThuc;
  final String? hinhThucNghiemThu;
  final String? moTaCongViec;
  final int? soNguoiThucHien;
  final String? khuVucThucHien;
  final int? khoiLuongCongViec;
  final String? yeuCauCongViec;
  final String? thoiGianBatDau; // Storing TIME as String
  final String? thoiGianKetThuc; // Storing TIME as String (was text, assuming it might be a formatted time string or duration)
  final String? loaiMaySuDung;
  final String? congCuSuDung;
  final String? hoaChatSuDung;
  final String? ghiChu;
   String? xacNhan;
   String? chiDinh;
   String? huongDan;
   String? nhomThucHien;
   String? caNhanThucHien;
   String? listNguoiThucHien;

  GoCleanYeuCauModel({
    this.giaoViecID,
    this.nguoiTao,
    this.nguoiNghiemThu,
    this.diaDiem,
    this.diaChi,
    this.dinhVi,
    this.lapLai,
    this.ngayBatDau,
    this.ngayKetThuc,
    this.hinhThucNghiemThu,
    this.moTaCongViec,
    this.soNguoiThucHien,
    this.khuVucThucHien,
    this.khoiLuongCongViec,
    this.yeuCauCongViec,
    this.thoiGianBatDau,
    this.thoiGianKetThuc,
    this.loaiMaySuDung,
    this.congCuSuDung,
    this.hoaChatSuDung,
    this.ghiChu,
    this.xacNhan,
    this.chiDinh,
    this.huongDan,
    this.nhomThucHien,
    this.caNhanThucHien,
    this.listNguoiThucHien,
  });

  Map<String, dynamic> toMap() => {
    'GiaoViecID': giaoViecID,
    'NguoiTao': nguoiTao,
    'NguoiNghiemThu': nguoiNghiemThu,
    'DiaDiem': diaDiem,
    'DiaChi': diaChi,
    'DinhVi': dinhVi,
    'LapLai': lapLai,
    'NgayBatDau': ngayBatDau?.toIso8601String().split('T').first,
    'NgayKetThuc': ngayKetThuc?.toIso8601String().split('T').first,
    'HinhThucNghiemThu': hinhThucNghiemThu,
    'MoTaCongViec': moTaCongViec,
    'SoNguoiThucHien': soNguoiThucHien,
    'KhuVucThucHien': khuVucThucHien,
    'KhoiLuongCongViec': khoiLuongCongViec,
    'YeuCauCongViec': yeuCauCongViec,
    'ThoiGianBatDau': thoiGianBatDau,
    'ThoiGianKetThuc': thoiGianKetThuc,
    'LoaiMaySuDung': loaiMaySuDung,
    'CongCuSuDung': congCuSuDung,
    'HoaChatSuDung': hoaChatSuDung,
    'GhiChu': ghiChu,
    'XacNhan': xacNhan,
    'ChiDinh': chiDinh,
    'HuongDan': huongDan,
    'NhomThucHien': nhomThucHien,
    'CaNhanThucHien': caNhanThucHien,
    'ListNguoiThucHien': listNguoiThucHien,
  };

  factory GoCleanYeuCauModel.fromMap(Map<dynamic, dynamic> map) {
    return GoCleanYeuCauModel(
      giaoViecID: map['GiaoViecID']?.toString(),
      nguoiTao: map['NguoiTao']?.toString(),
      nguoiNghiemThu: map['NguoiNghiemThu']?.toString(),
      diaDiem: map['DiaDiem']?.toString(),
      diaChi: map['DiaChi']?.toString(),
      dinhVi: map['DinhVi']?.toString(),
      lapLai: map['LapLai']?.toString(),
      ngayBatDau: map['NgayBatDau'] != null ? DateTime.tryParse(map['NgayBatDau'].toString()) : null,
      ngayKetThuc: map['NgayKetThuc'] != null ? DateTime.tryParse(map['NgayKetThuc'].toString()) : null,
      hinhThucNghiemThu: map['HinhThucNghiemThu']?.toString(),
      moTaCongViec: map['MoTaCongViec']?.toString(),
      soNguoiThucHien: map['SoNguoiThucHien'] != null ? int.tryParse(map['SoNguoiThucHien'].toString()) : null,
      khuVucThucHien: map['KhuVucThucHien']?.toString(),
      khoiLuongCongViec: map['KhoiLuongCongViec'] != null ? int.tryParse(map['KhoiLuongCongViec'].toString()) : null,
      yeuCauCongViec: map['YeuCauCongViec']?.toString(),
      thoiGianBatDau: map['ThoiGianBatDau']?.toString(),
      thoiGianKetThuc: map['ThoiGianKetThuc']?.toString(), // Was text
      loaiMaySuDung: map['LoaiMaySuDung']?.toString(),
      congCuSuDung: map['CongCuSuDung']?.toString(),
      hoaChatSuDung: map['HoaChatSuDung']?.toString(),
      ghiChu: map['GhiChu']?.toString(),
      xacNhan: map['XacNhan']?.toString(),
      chiDinh: map['ChiDinh']?.toString(),
      huongDan: map['HuongDan']?.toString(),
      nhomThucHien: map['NhomThucHien']?.toString(),
      caNhanThucHien: map['CaNhanThucHien']?.toString(),
      listNguoiThucHien: map['ListNguoiThucHien']?.toString(),
    );
  }
}
class KhachHangModel {
  final String? uid;
  final String? nguoiDung;
  final String? chiaSe;
  final String? danhDau;
  final String? vungMien;
  final String? phanLoai;
  final String? loaiHinh;
  final String? loaiCongTrinh;
  final String? maBP;
  final String? maKT;
  final String? maKD;
  final String? trangThaiHopDong;
  final String? tenDuAn;
  final String? tenKyThuat;
  final String? tenRutGon;
  final String? tenVatTu;
  final String? giamSat;
  final String? qldv;
  final String? ghiChu;
  final String? diaChi;
  final String? diaChiVanPhong;
  final String? sdtDuAn;
  final double? nhanSuTheoHopDong;
  final double? nhanSuDuocCo;
  final String? hinhAnh;
  final String? maSoThue;
  final String? soDienThoai;
  final String? fax;
  final String? website;
  final String? email;
  final String? soTaiKhoan;
  final String? nganHang;
  final DateTime? ngayCapNhatCuoi;
  final DateTime? ngayKhoiTao;
  final String? loaiMuaHang;
  final String? tinhThanh;
  final String? quanHuyen;
  final String? phuongXa;
  final String? kenhTiepCan;
  final String? duKienTrienKhai;
  final String? tiemNangDVTM;
  final String? yeuCauNhanSu;
  final String? cachThucTuyen;
  final String? mucLuongTuyen;
  final String? luongBP;

  KhachHangModel({
    this.uid,
    this.nguoiDung,
    this.chiaSe,
    this.danhDau,
    this.vungMien,
    this.phanLoai,
    this.loaiHinh,
    this.loaiCongTrinh,
    this.maBP,
    this.maKT,
    this.maKD,
    this.trangThaiHopDong,
    this.tenDuAn,
    this.tenKyThuat,
    this.tenRutGon,
    this.tenVatTu,
    this.giamSat,
    this.qldv,
    this.ghiChu,
    this.diaChi,
    this.diaChiVanPhong,
    this.sdtDuAn,
    this.nhanSuTheoHopDong,
    this.nhanSuDuocCo,
    this.hinhAnh,
    this.maSoThue,
    this.soDienThoai,
    this.fax,
    this.website,
    this.email,
    this.soTaiKhoan,
    this.nganHang,
    this.ngayCapNhatCuoi,
    this.ngayKhoiTao,
    this.loaiMuaHang,
    this.tinhThanh,
    this.quanHuyen,
    this.phuongXa,
    this.kenhTiepCan,
    this.duKienTrienKhai,
    this.tiemNangDVTM,
    this.yeuCauNhanSu,
    this.cachThucTuyen,
    this.mucLuongTuyen,
    this.luongBP,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nguoiDung': nguoiDung,
    'chiaSe': chiaSe,
    'danhDau': danhDau,
    'vungMien': vungMien,
    'phanLoai': phanLoai,
    'loaiHinh': loaiHinh,
    'loaiCongTrinh': loaiCongTrinh,
    'maBP': maBP,
    'maKT': maKT,
    'maKD': maKD,
    'trangThaiHopDong': trangThaiHopDong,
    'tenDuAn': tenDuAn,
    'tenKyThuat': tenKyThuat,
    'tenRutGon': tenRutGon,
    'tenVatTu': tenVatTu,
    'giamSat': giamSat,
    'qldv': qldv,
    'ghiChu': ghiChu,
    'diaChi': diaChi,
    'diaChiVanPhong': diaChiVanPhong,
    'sdtDuAn': sdtDuAn,
    'nhanSuTheoHopDong': nhanSuTheoHopDong,
    'nhanSuDuocCo': nhanSuDuocCo,
    'hinhAnh': hinhAnh,
    'maSoThue': maSoThue,
    'soDienThoai': soDienThoai,
    'fax': fax,
    'website': website,
    'email': email,
    'soTaiKhoan': soTaiKhoan,
    'nganHang': nganHang,
    'ngayCapNhatCuoi': ngayCapNhatCuoi?.toIso8601String().split('T').first,
    'ngayKhoiTao': ngayKhoiTao?.toIso8601String().split('T').first,
    'loaiMuaHang': loaiMuaHang,
    'tinhThanh': tinhThanh,
    'quanHuyen': quanHuyen,
    'phuongXa': phuongXa,
    'kenhTiepCan': kenhTiepCan,
    'duKienTrienKhai': duKienTrienKhai,
    'tiemNangDVTM': tiemNangDVTM,
    'yeuCauNhanSu': yeuCauNhanSu,
    'cachThucTuyen': cachThucTuyen,
    'mucLuongTuyen': mucLuongTuyen,
    'luongBP': luongBP,
  };

  factory KhachHangModel.fromMap(Map<dynamic, dynamic> map) {
    return KhachHangModel(
      uid: map['uid']?.toString(),
      nguoiDung: map['nguoiDung']?.toString(),
      chiaSe: map['chiaSe']?.toString(),
      danhDau: map['danhDau']?.toString(),
      vungMien: map['vungMien']?.toString(),
      phanLoai: map['phanLoai']?.toString(),
      loaiHinh: map['loaiHinh']?.toString(),
      loaiCongTrinh: map['loaiCongTrinh']?.toString(),
      maBP: map['maBP']?.toString(),
      maKT: map['maKT']?.toString(),
      maKD: map['maKD']?.toString(),
      trangThaiHopDong: map['trangThaiHopDong']?.toString(),
      tenDuAn: map['tenDuAn']?.toString(),
      tenKyThuat: map['tenKyThuat']?.toString(),
      tenRutGon: map['tenRutGon']?.toString(),
      tenVatTu: map['tenVatTu']?.toString(),
      giamSat: map['giamSat']?.toString(),
      qldv: map['qldv']?.toString(),
      ghiChu: map['ghiChu']?.toString(),
      diaChi: map['diaChi']?.toString(),
      diaChiVanPhong: map['diaChiVanPhong']?.toString(),
      sdtDuAn: map['sdtDuAn']?.toString(),
      nhanSuTheoHopDong: map['nhanSuTheoHopDong'] != null ? double.tryParse(map['nhanSuTheoHopDong'].toString()) : null,
      nhanSuDuocCo: map['nhanSuDuocCo'] != null ? double.tryParse(map['nhanSuDuocCo'].toString()) : null,
      hinhAnh: map['hinhAnh']?.toString(),
      maSoThue: map['maSoThue']?.toString(),
      soDienThoai: map['soDienThoai']?.toString(),
      fax: map['fax']?.toString(),
      website: map['website']?.toString(),
      email: map['email']?.toString(),
      soTaiKhoan: map['soTaiKhoan']?.toString(),
      nganHang: map['nganHang']?.toString(),
      ngayCapNhatCuoi: map['ngayCapNhatCuoi'] != null ? DateTime.tryParse(map['ngayCapNhatCuoi'].toString()) : null,
      ngayKhoiTao: map['ngayKhoiTao'] != null ? DateTime.tryParse(map['ngayKhoiTao'].toString()) : null,
      loaiMuaHang: map['loaiMuaHang']?.toString(),
      tinhThanh: map['tinhThanh']?.toString(),
      quanHuyen: map['quanHuyen']?.toString(),
      phuongXa: map['phuongXa']?.toString(),
      kenhTiepCan: map['kenhTiepCan']?.toString(),
      duKienTrienKhai: map['duKienTrienKhai']?.toString(),
      tiemNangDVTM: map['tiemNangDVTM']?.toString(),
      yeuCauNhanSu: map['yeuCauNhanSu']?.toString(),
      cachThucTuyen: map['cachThucTuyen']?.toString(),
      mucLuongTuyen: map['mucLuongTuyen']?.toString(),
      luongBP: map['luongBP']?.toString(),
    );
  }
}
class KhachHangContactModel {
  final String? uid;
  final String? boPhan;
  final String? hinhAnh;
  final String? nguoiDung;
  final String? chiaSe;
  final DateTime? ngayTao;
  final DateTime? ngayCapNhat;
  final String? hoSoYeuCau;
  final String? hoTen;
  final String? gioiTinh;
  final String? chucDanh;
  final String? tinhTrang;
  final String? chucNang;
  final String? thoiGianLamViec;
  final String? soDienThoai;
  final String? email;
  final String? soThich;
  final String? khongThich;
  final String? tinhCach;
  final String? yeuCauRiengVeDV;
  final String? gioLam;
  final String? nguyenTac;
  final String? kyVong;
  final String? soDienThoai2;
  final DateTime? sinhNhat;
  final String? diaChi;
  final String? tenNick;
  final String? nguonGoc;

  KhachHangContactModel({
    this.uid,
    this.boPhan,
    this.hinhAnh,
    this.nguoiDung,
    this.chiaSe,
    this.ngayTao,
    this.ngayCapNhat,
    this.hoSoYeuCau,
    this.hoTen,
    this.gioiTinh,
    this.chucDanh,
    this.tinhTrang,
    this.chucNang,
    this.thoiGianLamViec,
    this.soDienThoai,
    this.email,
    this.soThich,
    this.khongThich,
    this.tinhCach,
    this.yeuCauRiengVeDV,
    this.gioLam,
    this.nguyenTac,
    this.kyVong,
    this.soDienThoai2,
    this.sinhNhat,
    this.diaChi,
    this.tenNick,
    this.nguonGoc,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'boPhan': boPhan,
    'hinhAnh': hinhAnh,
    'nguoiDung': nguoiDung,
    'chiaSe': chiaSe,
    'ngayTao': ngayTao?.toIso8601String().split('T').first,
    'ngayCapNhat': ngayCapNhat?.toIso8601String().split('T').first,
    'hoSoYeuCau': hoSoYeuCau,
    'hoTen': hoTen,
    'gioiTinh': gioiTinh,
    'chucDanh': chucDanh,
    'tinhTrang': tinhTrang,
    'chucNang': chucNang,
    'thoiGianLamViec': thoiGianLamViec,
    'soDienThoai': soDienThoai,
    'email': email,
    'soThich': soThich,
    'khongThich': khongThich,
    'tinhCach': tinhCach,
    'yeuCauRiengVeDV': yeuCauRiengVeDV,
    'gioLam': gioLam,
    'nguyenTac': nguyenTac,
    'kyVong': kyVong,
    'soDienThoai2': soDienThoai2,
    'sinhNhat': sinhNhat?.toIso8601String().split('T').first,
    'diaChi': diaChi,
    'tenNick': tenNick,
    'nguonGoc': nguonGoc,
  };

  factory KhachHangContactModel.fromMap(Map<dynamic, dynamic> map) {
    return KhachHangContactModel(
      uid: map['uid']?.toString(),
      boPhan: map['boPhan']?.toString(),
      hinhAnh: map['hinhAnh']?.toString(),
      nguoiDung: map['nguoiDung']?.toString(),
      chiaSe: map['chiaSe']?.toString(),
      ngayTao: map['ngayTao'] != null ? DateTime.tryParse(map['ngayTao'].toString()) : null,
      ngayCapNhat: map['ngayCapNhat'] != null ? DateTime.tryParse(map['ngayCapNhat'].toString()) : null,
      hoSoYeuCau: map['hoSoYeuCau']?.toString(),
      hoTen: map['hoTen']?.toString(),
      gioiTinh: map['gioiTinh']?.toString(),
      chucDanh: map['chucDanh']?.toString(),
      tinhTrang: map['tinhTrang']?.toString(),
      chucNang: map['chucNang']?.toString(),
      thoiGianLamViec: map['thoiGianLamViec']?.toString(),
      soDienThoai: map['soDienThoai']?.toString(),
      email: map['email']?.toString(),
      soThich: map['soThich']?.toString(),
      khongThich: map['khongThich']?.toString(),
      tinhCach: map['tinhCach']?.toString(),
      yeuCauRiengVeDV: map['yeuCauRiengVeDV']?.toString(),
      gioLam: map['gioLam']?.toString(),
      nguyenTac: map['nguyenTac']?.toString(),
      kyVong: map['kyVong']?.toString(),
      soDienThoai2: map['soDienThoai2']?.toString(),
      sinhNhat: map['sinhNhat'] != null ? DateTime.tryParse(map['sinhNhat'].toString()) : null,
      diaChi: map['diaChi']?.toString(),
      tenNick: map['tenNick']?.toString(),
      nguonGoc: map['nguonGoc']?.toString(),
    );
  }
}
class LinkHopDongModel {
 final String? uid;
 final String? thang;
 final String? nguoiTao;
 final String? vungMien;
 final String? ngayCapNhatCuoi;
 final String? maKeToan;
 final String? maKinhDoanh;
 final String? trangThai;
 final String? tenHopDong;
 final String? diaChi;
 final String? loaiHinh;
 final double? congNhanHopDong;
 final double? congNhanHDTang;
 final double? congNhanHDGiam;
 final double? congNhanDuocCo;
 final double? giamSatCoDinh;
 final int? doanhThuCu;
 final int? comCu;
 final int? comCu10phantram;
 final int? comKHThucNhan;
 final int? comGiam;
 final int? comTangKhongThue;
 final int? comTangTinhThue;
 final int? doanhThuTangCNGia;
 final int? doanhThuGiamCNGia;
 final String? ghiChuHopDong;
 final int? thoiHanHopDong;
 final String? thoiHanBatDau;
 final String? thoiHanKetthuc;
 final String? soHopDong;
 final int? doanhThuDangThucHien;
 final int? doanhThuXuatHoaDon;
 final int? doanhThuChenhLech;
 final int? comMoi;
 final int? phanTramThueMoi;
 final int? comThucNhan;
 final String? comTenKhachHang;
 final int? chiPhiGiamSat;
 final int? chiPhiVatLieu;
 final int? chiPhiCVDinhKy;
 final int? chiPhiLeTetTCa;
 final int? chiPhiPhuCap;
 final int? chiPhiNgoaiGiao;
 final int? chiPhiMayMoc;
 final int? chiPhiLuong;
 final int? giaTriConLai;
 final int? netCN;
 final int? giaNetCN;
 final String? netVung;
 final int? chenhLechGia;
 final int? chenhLechTong;
 final String? daoHanHopDong;
 final String? congViecCanGiaiQuyet;
 final String? congNhanCa1;
 final String? congNhanCa2;
 final String? congNhanCa3;
 final String? congNhanCaHC;
 final String? congNhanCaKhac;
 final String? congNhanGhiChuBoTriNhanSu;
 final String? fileHopDong;

 LinkHopDongModel({
   this.uid,
   this.thang,
   this.nguoiTao,
   this.vungMien,
   this.ngayCapNhatCuoi,
   this.maKeToan,
   this.maKinhDoanh,
   this.trangThai,
   this.tenHopDong,
   this.diaChi,
   this.loaiHinh,
   this.congNhanHopDong,
   this.congNhanHDTang,
   this.congNhanHDGiam,
   this.congNhanDuocCo,
   this.giamSatCoDinh,
   this.doanhThuCu,
   this.comCu,
   this.comCu10phantram,
   this.comKHThucNhan,
   this.comGiam,
   this.comTangKhongThue,
   this.comTangTinhThue,
   this.doanhThuTangCNGia,
   this.doanhThuGiamCNGia,
   this.ghiChuHopDong,
   this.thoiHanHopDong,
   this.thoiHanBatDau,
   this.thoiHanKetthuc,
   this.soHopDong,
   this.doanhThuDangThucHien,
   this.doanhThuXuatHoaDon,
   this.doanhThuChenhLech,
   this.comMoi,
   this.phanTramThueMoi,
   this.comThucNhan,
   this.comTenKhachHang,
   this.chiPhiGiamSat,
   this.chiPhiVatLieu,
   this.chiPhiCVDinhKy,
   this.chiPhiLeTetTCa,
   this.chiPhiPhuCap,
   this.chiPhiNgoaiGiao,
   this.chiPhiMayMoc,
   this.chiPhiLuong,
   this.giaTriConLai,
   this.netCN,
   this.giaNetCN,
   this.netVung,
   this.chenhLechGia,
   this.chenhLechTong,
   this.daoHanHopDong,
   this.congViecCanGiaiQuyet,
   this.congNhanCa1,
   this.congNhanCa2,
   this.congNhanCa3,
   this.congNhanCaHC,
   this.congNhanCaKhac,
   this.congNhanGhiChuBoTriNhanSu,
   this.fileHopDong,
 });

 Map<String, dynamic> toMap() => {
   'UID': uid,
   'Thang': thang,
   'NguoiTao': nguoiTao,
   'VungMien': vungMien,
   'NgayCapNhatCuoi': ngayCapNhatCuoi,
   'MaKeToan': maKeToan,
   'MaKinhDoanh': maKinhDoanh,
   'TrangThai': trangThai,
   'TenHopDong': tenHopDong,
   'DiaChi': diaChi,
   'LoaiHinh': loaiHinh,
   'CongNhanHopDong': congNhanHopDong,
   'CongNhanHDTang': congNhanHDTang,
   'CongNhanHDGiam': congNhanHDGiam,
   'CongNhanDuocCo': congNhanDuocCo,
   'GiamSatCoDinh': giamSatCoDinh,
   'DoanhThuCu': doanhThuCu,
   'ComCu': comCu,
   'ComCu10phantram': comCu10phantram,
   'ComKHThucNhan': comKHThucNhan,
   'ComGiam': comGiam,
   'ComTangKhongThue': comTangKhongThue,
   'ComTangTinhThue': comTangTinhThue,
   'DoanhThuTangCNGia': doanhThuTangCNGia,
   'DoanhThuGiamCNGia': doanhThuGiamCNGia,
   'GhiChuHopDong': ghiChuHopDong,
   'ThoiHanHopDong': thoiHanHopDong,
   'ThoiHanBatDau': thoiHanBatDau,
   'ThoiHanKetthuc': thoiHanKetthuc,
   'SoHopDong': soHopDong,
   'DoanhThuDangThucHien': doanhThuDangThucHien,
   'DoanhThuXuatHoaDon': doanhThuXuatHoaDon,
   'DoanhThuChenhLech': doanhThuChenhLech,
   'ComMoi': comMoi,
   'PhanTramThueMoi': phanTramThueMoi,
   'ComThucNhan': comThucNhan,
   'ComTenKhachHang': comTenKhachHang,
   'ChiPhiGiamSat': chiPhiGiamSat,
   'ChiPhiVatLieu': chiPhiVatLieu,
   'ChiPhiCVDinhKy': chiPhiCVDinhKy,
   'ChiPhiLeTetTCa': chiPhiLeTetTCa,
   'ChiPhiPhuCap': chiPhiPhuCap,
   'ChiPhiNgoaiGiao': chiPhiNgoaiGiao,
   'ChiPhiMayMoc': chiPhiMayMoc,
   'ChiPhiLuong': chiPhiLuong,
   'GiaTriConLai': giaTriConLai,
   'NetCN': netCN,
   'GiaNetCN': giaNetCN,
   'NetVung': netVung,
   'ChenhLechGia': chenhLechGia,
   'ChenhLechTong': chenhLechTong,
   'DaoHanHopDong': daoHanHopDong,
   'CongViecCanGiaiQuyet': congViecCanGiaiQuyet,
   'CongNhanCa1': congNhanCa1,
   'CongNhanCa2': congNhanCa2,
   'CongNhanCa3': congNhanCa3,
   'CongNhanCaHC': congNhanCaHC,
   'CongNhanCaKhac': congNhanCaKhac,
   'CongNhanGhiChuBoTriNhanSu': congNhanGhiChuBoTriNhanSu,
   'FileHopDong': fileHopDong,
 };

 factory LinkHopDongModel.fromMap(Map<dynamic, dynamic> map) {
   return LinkHopDongModel(
     uid: map['uid']?.toString(),
     thang: map['thang']?.toString(),
     nguoiTao: map['nguoiTao']?.toString(),
     vungMien: map['vungMien']?.toString(),
     ngayCapNhatCuoi: map['ngayCapNhatCuoi']?.toString(),
     maKeToan: map['maKeToan']?.toString(),
     maKinhDoanh: map['maKinhDoanh']?.toString(),
     trangThai: map['trangThai']?.toString(),
     tenHopDong: map['tenHopDong']?.toString(),
     diaChi: map['diaChi']?.toString(),
     loaiHinh: map['loaiHinh']?.toString(),
     congNhanHopDong: map['congNhanHopDong']?.toDouble(),
     congNhanHDTang: map['congNhanHDTang']?.toDouble(),
     congNhanHDGiam: map['congNhanHDGiam']?.toDouble(),
     congNhanDuocCo: map['congNhanDuocCo']?.toDouble(),
     giamSatCoDinh: map['giamSatCoDinh']?.toDouble(),
     doanhThuCu: map['doanhThuCu']?.toInt(),
     comCu: map['comCu']?.toInt(),
     comCu10phantram: map['comCu10phantram']?.toInt(),
     comKHThucNhan: map['comKHThucNhan']?.toInt(),
     comGiam: map['comGiam']?.toInt(),
     comTangKhongThue: map['comTangKhongThue']?.toInt(),
     comTangTinhThue: map['comTangTinhThue']?.toInt(),
     doanhThuTangCNGia: map['doanhThuTangCNGia']?.toInt(),
     doanhThuGiamCNGia: map['doanhThuGiamCNGia']?.toInt(),
     ghiChuHopDong: map['ghiChuHopDong']?.toString(),
     thoiHanHopDong: map['thoiHanHopDong']?.toInt(),
     thoiHanBatDau: map['thoiHanBatDau']?.toString(),
     thoiHanKetthuc: map['thoiHanKetthuc']?.toString(),
     soHopDong: map['soHopDong']?.toString(),
     doanhThuDangThucHien: map['doanhThuDangThucHien']?.toInt(),
     doanhThuXuatHoaDon: map['doanhThuXuatHoaDon']?.toInt(),
     doanhThuChenhLech: map['doanhThuChenhLech']?.toInt(),
     comMoi: map['comMoi']?.toInt(),
     phanTramThueMoi: map['phanTramThueMoi']?.toInt(),
     comThucNhan: map['comThucNhan']?.toInt(),
     comTenKhachHang: map['comTenKhachHang']?.toString(),
     chiPhiGiamSat: map['chiPhiGiamSat']?.toInt(),
     chiPhiVatLieu: map['chiPhiVatLieu']?.toInt(),
     chiPhiCVDinhKy: map['chiPhiCVDinhKy']?.toInt(),
     chiPhiLeTetTCa: map['chiPhiLeTetTCa']?.toInt(),
     chiPhiPhuCap: map['chiPhiPhuCap']?.toInt(),
     chiPhiNgoaiGiao: map['chiPhiNgoaiGiao']?.toInt(),
     chiPhiMayMoc: map['chiPhiMayMoc']?.toInt(),
     chiPhiLuong: map['chiPhiLuong']?.toInt(),
     giaTriConLai: map['giaTriConLai']?.toInt(),
     netCN: map['netCN']?.toInt(),
     giaNetCN: map['giaNetCN']?.toInt(),
     netVung: map['netVung']?.toString(),
     chenhLechGia: map['chenhLechGia']?.toInt(),
     chenhLechTong: map['chenhLechTong']?.toInt(),
     daoHanHopDong: map['daoHanHopDong']?.toString(),
     congViecCanGiaiQuyet: map['congViecCanGiaiQuyet']?.toString(),
     congNhanCa1: map['congNhanCa1']?.toString(),
     congNhanCa2: map['congNhanCa2']?.toString(),
     congNhanCa3: map['congNhanCa3']?.toString(),
     congNhanCaHC: map['congNhanCaHC']?.toString(),
     congNhanCaKhac: map['congNhanCaKhac']?.toString(),
     congNhanGhiChuBoTriNhanSu: map['congNhanGhiChuBoTriNhanSu']?.toString(),
     fileHopDong: map['fileHopDong']?.toString(),
   );
 }
}

class LinkVatTuModel {
 final String? uid;
 final String? hopDongID;
 final String? thang;
 final String? nguoiTao;
 final String? maKinhDoanh;
 final String? danhMucVatTuTieuHao;
 final String? nhanHieu;
 final String? quyCach;
 final String? donViTinh;
 final int? donGiaCapKhachHang;
 final double? soLuong;
 final int? thanhTien;

 LinkVatTuModel({
   this.uid,
   this.hopDongID,
   this.thang,
   this.nguoiTao,
   this.maKinhDoanh,
   this.danhMucVatTuTieuHao,
   this.nhanHieu,
   this.quyCach,
   this.donViTinh,
   this.donGiaCapKhachHang,
   this.soLuong,
   this.thanhTien,
 });

 Map<String, dynamic> toMap() => {
   'UID': uid,
   'HopDongID': hopDongID,
   'Thang': thang,
   'NguoiTao': nguoiTao,
   'MaKinhDoanh': maKinhDoanh,
   'DanhMucVatTuTieuHao': danhMucVatTuTieuHao,
   'NhanHieu': nhanHieu,
   'QuyCach': quyCach,
   'DonViTinh': donViTinh,
   'DonGiaCapKhachHang': donGiaCapKhachHang,
   'SoLuong': soLuong,
   'ThanhTien': thanhTien,
 };

 factory LinkVatTuModel.fromMap(Map<dynamic, dynamic> map) {
   return LinkVatTuModel(
     uid: map['uid']?.toString(),
     hopDongID: map['hopDongID']?.toString(),
     thang: map['thang']?.toString(),
     nguoiTao: map['nguoiTao']?.toString(),
     maKinhDoanh: map['maKinhDoanh']?.toString(),
     danhMucVatTuTieuHao: map['danhMucVatTuTieuHao']?.toString(),
     nhanHieu: map['nhanHieu']?.toString(),
     quyCach: map['quyCach']?.toString(),
     donViTinh: map['donViTinh']?.toString(),
     donGiaCapKhachHang: map['donGiaCapKhachHang']?.toInt(),
     soLuong: map['soLuong']?.toDouble(),
     thanhTien: map['thanhTien']?.toInt(),
   );
 }
 LinkVatTuModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? danhMucVatTuTieuHao,
  String? nhanHieu,
  String? quyCach,
  String? donViTinh,
  int? donGiaCapKhachHang,
  double? soLuong,
  int? thanhTien,
}) {
  return LinkVatTuModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    danhMucVatTuTieuHao: danhMucVatTuTieuHao ?? this.danhMucVatTuTieuHao,
    nhanHieu: nhanHieu ?? this.nhanHieu,
    quyCach: quyCach ?? this.quyCach,
    donViTinh: donViTinh ?? this.donViTinh,
    donGiaCapKhachHang: donGiaCapKhachHang ?? this.donGiaCapKhachHang,
    soLuong: soLuong ?? this.soLuong,
    thanhTien: thanhTien ?? this.thanhTien,
  );
}
}

class LinkDinhKyModel {
 final String? uid;
 final String? hopDongID;
 final String? thang;
 final String? nguoiTao;
 final String? maKinhDoanh;
 final String? danhMucCongViec;
 final String? chiTietCongViec;
 final int? tongTienTrenLanThucHien;
 final double? tanSuatThucHienTrenThang;
 final int? donGiaTrenThang;
 final double? soLuong;
 final int? thanhTien;
 final String? ghiChu;

 LinkDinhKyModel({
   this.uid,
   this.hopDongID,
   this.thang,
   this.nguoiTao,
   this.maKinhDoanh,
   this.danhMucCongViec,
   this.chiTietCongViec,
   this.tongTienTrenLanThucHien,
   this.tanSuatThucHienTrenThang,
   this.donGiaTrenThang,
   this.soLuong,
   this.thanhTien,
   this.ghiChu,
 });

 Map<String, dynamic> toMap() => {
   'UID': uid,
   'HopDongID': hopDongID,
   'Thang': thang,
   'NguoiTao': nguoiTao,
   'MaKinhDoanh': maKinhDoanh,
   'DanhMucCongViec': danhMucCongViec,
   'ChiTietCongViec': chiTietCongViec,
   'TongTienTrenLanThucHien': tongTienTrenLanThucHien,
   'TanSuatThucHienTrenThang': tanSuatThucHienTrenThang,
   'DonGiaTrenThang': donGiaTrenThang,
   'SoLuong': soLuong,
   'ThanhTien': thanhTien,
   'GhiChu': ghiChu,
 };

 factory LinkDinhKyModel.fromMap(Map<dynamic, dynamic> map) {
   return LinkDinhKyModel(
     uid: map['uid']?.toString(),
     hopDongID: map['hopDongID']?.toString(),
     thang: map['thang']?.toString(),
     nguoiTao: map['nguoiTao']?.toString(),
     maKinhDoanh: map['maKinhDoanh']?.toString(),
     danhMucCongViec: map['danhMucCongViec']?.toString(),
     chiTietCongViec: map['chiTietCongViec']?.toString(),
     tongTienTrenLanThucHien: map['tongTienTrenLanThucHien']?.toInt(),
     tanSuatThucHienTrenThang: map['tanSuatThucHienTrenThang']?.toDouble(),
     donGiaTrenThang: map['donGiaTrenThang']?.toInt(),
     soLuong: map['soLuong']?.toDouble(),
     thanhTien: map['thanhTien']?.toInt(),
     ghiChu: map['ghiChu']?.toString(),
   );
 }
 LinkDinhKyModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? danhMucCongViec,
  String? chiTietCongViec,
  int? tongTienTrenLanThucHien,
  double? tanSuatThucHienTrenThang,
  int? donGiaTrenThang,
  double? soLuong,
  int? thanhTien,
  String? ghiChu,
}) {
  return LinkDinhKyModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    danhMucCongViec: danhMucCongViec ?? this.danhMucCongViec,
    chiTietCongViec: chiTietCongViec ?? this.chiTietCongViec,
    tongTienTrenLanThucHien: tongTienTrenLanThucHien ?? this.tongTienTrenLanThucHien,
    tanSuatThucHienTrenThang: tanSuatThucHienTrenThang ?? this.tanSuatThucHienTrenThang,
    donGiaTrenThang: donGiaTrenThang ?? this.donGiaTrenThang,
    soLuong: soLuong ?? this.soLuong,
    thanhTien: thanhTien ?? this.thanhTien,
    ghiChu: ghiChu ?? this.ghiChu,
  );
}
}

class LinkLeTetTCModel {
 final String? uid;
 final String? hopDongID;
 final String? thang;
 final String? nguoiTao;
 final String? maKinhDoanh;
 final String? danhMucCongViec;
 final String? chiTietCongViec;
 final String? tanSuatTrenLan;
 final String? donViTinh;
 final int? donGia;
 final double? soLuongNhanVien;
 final double? thoiGianCungCapDVT;
 final double? phanBoTrenThang;
 final int? thanhTienTrenThang;
 final String? ghiChu;

 LinkLeTetTCModel({
   this.uid,
   this.hopDongID,
   this.thang,
   this.nguoiTao,
   this.maKinhDoanh,
   this.danhMucCongViec,
   this.chiTietCongViec,
   this.tanSuatTrenLan,
   this.donViTinh,
   this.donGia,
   this.soLuongNhanVien,
   this.thoiGianCungCapDVT,
   this.phanBoTrenThang,
   this.thanhTienTrenThang,
   this.ghiChu,
 });

 Map<String, dynamic> toMap() => {
   'UID': uid,
   'HopDongID': hopDongID,
   'Thang': thang,
   'NguoiTao': nguoiTao,
   'MaKinhDoanh': maKinhDoanh,
   'DanhMucCongViec': danhMucCongViec,
   'ChiTietCongViec': chiTietCongViec,
   'TanSuatTrenLan': tanSuatTrenLan,
   'DonViTinh': donViTinh,
   'DonGia': donGia,
   'SoLuongNhanVien': soLuongNhanVien,
   'ThoiGianCungCapDVT': thoiGianCungCapDVT,
   'PhanBoTrenThang': phanBoTrenThang,
   'ThanhTienTrenThang': thanhTienTrenThang,
   'GhiChu': ghiChu,
 };

 factory LinkLeTetTCModel.fromMap(Map<dynamic, dynamic> map) {
   return LinkLeTetTCModel(
     uid: map['uid']?.toString(),
     hopDongID: map['hopDongID']?.toString(),
     thang: map['thang']?.toString(),
     nguoiTao: map['nguoiTao']?.toString(),
     maKinhDoanh: map['maKinhDoanh']?.toString(),
     danhMucCongViec: map['danhMucCongViec']?.toString(),
     chiTietCongViec: map['chiTietCongViec']?.toString(),
     tanSuatTrenLan: map['tanSuatTrenLan']?.toString(),
     donViTinh: map['donViTinh']?.toString(),
     donGia: map['donGia']?.toInt(),
     soLuongNhanVien: map['soLuongNhanVien']?.toDouble(),
     thoiGianCungCapDVT: map['thoiGianCungCapDVT']?.toDouble(),
     phanBoTrenThang: map['phanBoTrenThang']?.toDouble(),
     thanhTienTrenThang: map['thanhTienTrenThang']?.toInt(),
     ghiChu: map['ghiChu']?.toString(),
   );
 }
 LinkLeTetTCModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? danhMucCongViec,
  String? chiTietCongViec,
  String? tanSuatTrenLan,
  String? donViTinh,
  int? donGia,
  double? soLuongNhanVien,
  double? thoiGianCungCapDVT,
  double? phanBoTrenThang,
  int? thanhTienTrenThang,
  String? ghiChu,
}) {
  return LinkLeTetTCModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    danhMucCongViec: danhMucCongViec ?? this.danhMucCongViec,
    chiTietCongViec: chiTietCongViec ?? this.chiTietCongViec,
    tanSuatTrenLan: tanSuatTrenLan ?? this.tanSuatTrenLan,
    donViTinh: donViTinh ?? this.donViTinh,
    donGia: donGia ?? this.donGia,
    soLuongNhanVien: soLuongNhanVien ?? this.soLuongNhanVien,
    thoiGianCungCapDVT: thoiGianCungCapDVT ?? this.thoiGianCungCapDVT,
    phanBoTrenThang: phanBoTrenThang ?? this.phanBoTrenThang,
    thanhTienTrenThang: thanhTienTrenThang ?? this.thanhTienTrenThang,
    ghiChu: ghiChu ?? this.ghiChu,
  );
}
}

class LinkPhuCapModel {
 final String? uid;
 final String? hopDongID;
 final String? thang;
 final String? nguoiTao;
 final String? maKinhDoanh;
 final String? danhMucCongViec;
 final String? chiTietCongViec;
 final String? tanSuatTrenLan;
 final String? donViTinh;
 final int? donGia;
 final double? soLuongNhanVien;
 final double? thoiGianCungCapDVT;
 final double? phanBoTrenThang;
 final int? thanhTienTrenThang;
 final String? ghiChu;

 LinkPhuCapModel({
   this.uid,
   this.hopDongID,
   this.thang,
   this.nguoiTao,
   this.maKinhDoanh,
   this.danhMucCongViec,
   this.chiTietCongViec,
   this.tanSuatTrenLan,
   this.donViTinh,
   this.donGia,
   this.soLuongNhanVien,
   this.thoiGianCungCapDVT,
   this.phanBoTrenThang,
   this.thanhTienTrenThang,
   this.ghiChu,
 });

 Map<String, dynamic> toMap() => {
   'UID': uid,
   'HopDongID': hopDongID,
   'Thang': thang,
   'NguoiTao': nguoiTao,
   'MaKinhDoanh': maKinhDoanh,
   'DanhMucCongViec': danhMucCongViec,
   'ChiTietCongViec': chiTietCongViec,
   'TanSuatTrenLan': tanSuatTrenLan,
   'DonViTinh': donViTinh,
   'DonGia': donGia,
   'SoLuongNhanVien': soLuongNhanVien,
   'ThoiGianCungCapDVT': thoiGianCungCapDVT,
   'PhanBoTrenThang': phanBoTrenThang,
   'ThanhTienTrenThang': thanhTienTrenThang,
   'GhiChu': ghiChu,
 };

 factory LinkPhuCapModel.fromMap(Map<dynamic, dynamic> map) {
   return LinkPhuCapModel(
     uid: map['uid']?.toString(),
     hopDongID: map['hopDongID']?.toString(),
     thang: map['thang']?.toString(),
     nguoiTao: map['nguoiTao']?.toString(),
     maKinhDoanh: map['maKinhDoanh']?.toString(),
     danhMucCongViec: map['danhMucCongViec']?.toString(),
     chiTietCongViec: map['chiTietCongViec']?.toString(),
     tanSuatTrenLan: map['tanSuatTrenLan']?.toString(),
     donViTinh: map['donViTinh']?.toString(),
     donGia: map['donGia']?.toInt(),
     soLuongNhanVien: map['soLuongNhanVien']?.toDouble(),
     thoiGianCungCapDVT: map['thoiGianCungCapDVT']?.toDouble(),
     phanBoTrenThang: map['phanBoTrenThang']?.toDouble(),
     thanhTienTrenThang: map['thanhTienTrenThang']?.toInt(),
     ghiChu: map['ghiChu']?.toString(),
   );
 }
 LinkPhuCapModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? danhMucCongViec,
  String? chiTietCongViec,
  String? tanSuatTrenLan,
  String? donViTinh,
  int? donGia,
  double? soLuongNhanVien,
  double? thoiGianCungCapDVT,
  double? phanBoTrenThang,
  int? thanhTienTrenThang,
  String? ghiChu,
}) {
  return LinkPhuCapModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    danhMucCongViec: danhMucCongViec ?? this.danhMucCongViec,
    chiTietCongViec: chiTietCongViec ?? this.chiTietCongViec,
    tanSuatTrenLan: tanSuatTrenLan ?? this.tanSuatTrenLan,
    donViTinh: donViTinh ?? this.donViTinh,
    donGia: donGia ?? this.donGia,
    soLuongNhanVien: soLuongNhanVien ?? this.soLuongNhanVien,
    thoiGianCungCapDVT: thoiGianCungCapDVT ?? this.thoiGianCungCapDVT,
    phanBoTrenThang: phanBoTrenThang ?? this.phanBoTrenThang,
    thanhTienTrenThang: thanhTienTrenThang ?? this.thanhTienTrenThang,
    ghiChu: ghiChu ?? this.ghiChu,
  );
}
}

class LinkNgoaiGiaoModel {
 final String? uid;
 final String? hopDongID;
 final String? thang;
 final String? nguoiTao;
 final String? maKinhDoanh;
 final String? danhMuc;
 final String? noiDungChiTiet;
 final String? tanSuat;
 final String? donViTinh;
 final int? donGia;
 final double? soLuong;
 final double? thoiGianCungCapDVT;
 final double? phanBoTrenThang;
 final int? thanhTienTrenThang;
 final String? ghiChu;

 LinkNgoaiGiaoModel({
   this.uid,
   this.hopDongID,
   this.thang,
   this.nguoiTao,
   this.maKinhDoanh,
   this.danhMuc,
   this.noiDungChiTiet,
   this.tanSuat,
   this.donViTinh,
   this.donGia,
   this.soLuong,
   this.thoiGianCungCapDVT,
   this.phanBoTrenThang,
   this.thanhTienTrenThang,
   this.ghiChu,
 });

 Map<String, dynamic> toMap() => {
   'UID': uid,
   'HopDongID': hopDongID,
   'Thang': thang,
   'NguoiTao': nguoiTao,
   'MaKinhDoanh': maKinhDoanh,
   'DanhMuc': danhMuc,
   'NoiDungChiTiet': noiDungChiTiet,
   'TanSuat': tanSuat,
   'DonViTinh': donViTinh,
   'DonGia': donGia,
   'SoLuong': soLuong,
   'ThoiGianCungCapDVT': thoiGianCungCapDVT,
   'PhanBoTrenThang': phanBoTrenThang,
   'ThanhTienTrenThang': thanhTienTrenThang,
   'GhiChu': ghiChu,
  };

  factory LinkNgoaiGiaoModel.fromMap(Map<dynamic, dynamic> map) {
    return LinkNgoaiGiaoModel(
      uid: map['uid']?.toString(),
      hopDongID: map['hopDongID']?.toString(),
      thang: map['thang']?.toString(),
      nguoiTao: map['nguoiTao']?.toString(),
      maKinhDoanh: map['maKinhDoanh']?.toString(),
      danhMuc: map['danhMuc']?.toString(),
      noiDungChiTiet: map['noiDungChiTiet']?.toString(),
      tanSuat: map['tanSuat']?.toString(),
      donViTinh: map['donViTinh']?.toString(),
      donGia: map['donGia']?.toInt(),
      soLuong: map['soLuong']?.toDouble(),
      thoiGianCungCapDVT: map['thoiGianCungCapDVT']?.toDouble(),
      phanBoTrenThang: map['phanBoTrenThang']?.toDouble(),
      thanhTienTrenThang: map['thanhTienTrenThang']?.toInt(),
      ghiChu: map['ghiChu']?.toString(),
    );
  }
  LinkNgoaiGiaoModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? danhMuc,
  String? noiDungChiTiet,
  String? tanSuat,
  String? donViTinh,
  int? donGia,
  double? soLuong,
  double? thoiGianCungCapDVT,
  double? phanBoTrenThang,
  int? thanhTienTrenThang,
  String? ghiChu,
}) {
  return LinkNgoaiGiaoModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    danhMuc: danhMuc ?? this.danhMuc,
    noiDungChiTiet: noiDungChiTiet ?? this.noiDungChiTiet,
    tanSuat: tanSuat ?? this.tanSuat,
    donViTinh: donViTinh ?? this.donViTinh,
    donGia: donGia ?? this.donGia,
    soLuong: soLuong ?? this.soLuong,
    thoiGianCungCapDVT: thoiGianCungCapDVT ?? this.thoiGianCungCapDVT,
    phanBoTrenThang: phanBoTrenThang ?? this.phanBoTrenThang,
    thanhTienTrenThang: thanhTienTrenThang ?? this.thanhTienTrenThang,
    ghiChu: ghiChu ?? this.ghiChu,
  );
}
}

class LinkMayMocModel {
  final String? uid;
  final String? hopDongID;
  final String? thang;
  final String? nguoiTao;
  final String? maKinhDoanh;
  final String? loaiMay;
  final String? tenMay;
  final String? hangSanXuat;
  final String? tanSuat;
  final int? donGiaMay;
  final double? tinhTrangThietBi;
  final int? khauHao;
  final int? thanhTienMay;
  final int? soLuongCap;
  final int? thanhTienThang;
  final String? ghiChu;

  LinkMayMocModel({
    this.uid,
    this.hopDongID,
    this.thang,
    this.nguoiTao,
    this.maKinhDoanh,
    this.loaiMay,
    this.tenMay,
    this.hangSanXuat,
    this.tanSuat,
    this.donGiaMay,
    this.tinhTrangThietBi,
    this.khauHao,
    this.thanhTienMay,
    this.soLuongCap,
    this.thanhTienThang,
    this.ghiChu,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'HopDongID': hopDongID,
    'Thang': thang,
    'NguoiTao': nguoiTao,
    'MaKinhDoanh': maKinhDoanh,
    'LoaiMay': loaiMay,
    'TenMay': tenMay,
    'HangSanXuat': hangSanXuat,
    'TanSuat': tanSuat,
    'DonGiaMay': donGiaMay,
    'TinhTrangThietBi': tinhTrangThietBi,
    'KhauHao': khauHao,
    'ThanhTienMay': thanhTienMay,
    'SoLuongCap': soLuongCap,
    'ThanhTienThang': thanhTienThang,
    'GhiChu': ghiChu,
  };

  factory LinkMayMocModel.fromMap(Map<dynamic, dynamic> map) {
    return LinkMayMocModel(
      uid: map['uid']?.toString(),
      hopDongID: map['hopDongID']?.toString(),
      thang: map['thang']?.toString(),
      nguoiTao: map['nguoiTao']?.toString(),
      maKinhDoanh: map['maKinhDoanh']?.toString(),
      loaiMay: map['loaiMay']?.toString(),
      tenMay: map['tenMay']?.toString(),
      hangSanXuat: map['hangSanXuat']?.toString(),
      tanSuat: map['tanSuat']?.toString(),
      donGiaMay: map['donGiaMay']?.toInt(),
      tinhTrangThietBi: map['tinhTrangThietBi']?.toDouble(),
      khauHao: map['khauHao']?.toInt(),
      thanhTienMay: map['thanhTienMay']?.toInt(),
      soLuongCap: map['soLuongCap']?.toInt(),
      thanhTienThang: map['thanhTienThang']?.toInt(),
      ghiChu: map['ghiChu']?.toString(),
    );
  }
  LinkMayMocModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? loaiMay,
  String? tenMay,
  String? hangSanXuat,
  String? tanSuat,
  int? donGiaMay,
  double? tinhTrangThietBi,
  int? khauHao,
  int? thanhTienMay,
  int? soLuongCap,
  int? thanhTienThang,
  String? ghiChu,
}) {
  return LinkMayMocModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    loaiMay: loaiMay ?? this.loaiMay,
    tenMay: tenMay ?? this.tenMay,
    hangSanXuat: hangSanXuat ?? this.hangSanXuat,
    tanSuat: tanSuat ?? this.tanSuat,
    donGiaMay: donGiaMay ?? this.donGiaMay,
    tinhTrangThietBi: tinhTrangThietBi ?? this.tinhTrangThietBi,
    khauHao: khauHao ?? this.khauHao,
    thanhTienMay: thanhTienMay ?? this.thanhTienMay,
    soLuongCap: soLuongCap ?? this.soLuongCap,
    thanhTienThang: thanhTienThang ?? this.thanhTienThang,
    ghiChu: ghiChu ?? this.ghiChu,
  );
}
}

class LinkLuongModel {
  final String? uid;
  final String? hopDongID;
  final String? thang;
  final String? nguoiTao;
  final String? maKinhDoanh;
  final String? hangMuc;
  final String? moTa;
  final int? donGia;
  final double? soLuong;
  final int? thanhTien;

  LinkLuongModel({
    this.uid,
    this.hopDongID,
    this.thang,
    this.nguoiTao,
    this.maKinhDoanh,
    this.hangMuc,
    this.moTa,
    this.donGia,
    this.soLuong,
    this.thanhTien,
  });

  Map<String, dynamic> toMap() => {
    'UID': uid,
    'HopDongID': hopDongID,
    'Thang': thang,
    'NguoiTao': nguoiTao,
    'MaKinhDoanh': maKinhDoanh,
    'HangMuc': hangMuc,
    'MoTa': moTa,
    'DonGia': donGia,
    'SoLuong': soLuong,
    'ThanhTien': thanhTien,
  };

  factory LinkLuongModel.fromMap(Map<dynamic, dynamic> map) {
    return LinkLuongModel(
      uid: map['uid']?.toString(),
      hopDongID: map['hopDongID']?.toString(),
      thang: map['thang']?.toString(),
      nguoiTao: map['nguoiTao']?.toString(),
      maKinhDoanh: map['maKinhDoanh']?.toString(),
      hangMuc: map['hangMuc']?.toString(),
      moTa: map['moTa']?.toString(),
      donGia: map['donGia']?.toInt(),
      soLuong: map['soLuong']?.toDouble(),
      thanhTien: map['thanhTien']?.toInt(),
    );
  }
  LinkLuongModel copyWith({
  String? uid,
  String? hopDongID,
  String? thang,
  String? nguoiTao,
  String? maKinhDoanh,
  String? hangMuc,
  String? moTa,
  int? donGia,
  double? soLuong,
  int? thanhTien,
}) {
  return LinkLuongModel(
    uid: uid ?? this.uid,
    hopDongID: hopDongID ?? this.hopDongID,
    thang: thang ?? this.thang,
    nguoiTao: nguoiTao ?? this.nguoiTao,
    maKinhDoanh: maKinhDoanh ?? this.maKinhDoanh,
    hangMuc: hangMuc ?? this.hangMuc,
    moTa: moTa ?? this.moTa,
    donGia: donGia ?? this.donGia,
    soLuong: soLuong ?? this.soLuong,
    thanhTien: thanhTien ?? this.thanhTien,
  );
}
}
class LinkYeuCauMayModel {
  final String yeuCauId;
  String? nguoiTao;
  DateTime? ngay;
  String? gio;
  String? hopDongId;
  String? phanLoai;
  String? tenHopDong;
  String? diaChi;
  String? moTa;
  String? trangThai;
  String? nguoiGuiCapNhat;
  String? duyetKdCapNhat;
  String? duyetKtCapNhat;

  LinkYeuCauMayModel({
    required this.yeuCauId,
    this.nguoiTao,
    this.ngay,
    this.gio,
    this.hopDongId,
    this.phanLoai,
    this.tenHopDong,
    this.diaChi,
    this.moTa,
    this.trangThai,
    this.nguoiGuiCapNhat,
    this.duyetKdCapNhat,
    this.duyetKtCapNhat,
  });

  Map<String, dynamic> toMap() => {
        'yeuCauId': yeuCauId,
        'nguoiTao': nguoiTao,
        'ngay': ngay?.toIso8601String(),
        'gio': gio,
        'hopDongId': hopDongId,
        'phanLoai': phanLoai,
        'tenHopDong': tenHopDong,
        'diaChi': diaChi,
        'moTa': moTa,
        'trangThai': trangThai,
        'nguoiGuiCapNhat': nguoiGuiCapNhat,
        'duyetKdCapNhat': duyetKdCapNhat,
        'duyetKtCapNhat': duyetKtCapNhat,
      };

  factory LinkYeuCauMayModel.fromMap(Map<String, dynamic> map) {
    return LinkYeuCauMayModel(
      yeuCauId: map['yeuCauId'],
      nguoiTao: map['nguoiTao'],
      ngay: map['ngay'] != null ? DateTime.parse(map['ngay']) : null,
      gio: map['gio'],
      hopDongId: map['hopDongId'],
      phanLoai: map['phanLoai'],
      tenHopDong: map['tenHopDong'],
      diaChi: map['diaChi'],
      moTa: map['moTa'],
      trangThai: map['trangThai'],
      nguoiGuiCapNhat: map['nguoiGuiCapNhat'],
      duyetKdCapNhat: map['duyetKdCapNhat'],
      duyetKtCapNhat: map['duyetKtCapNhat'],
    );
  }
}
class LinkYeuCauMayChiTietModel {
  final String chiTietId;
  String? yeuCauId;
  String? loaiMay;
  String? maMay;
  String? hangMay;
  String? tanSuatSuDung;
  int? donGia;
  double? tinhTrang;
  int? soThangKhauHao;
  int? soLuong;
  int? thanhTienThang;
  String? ghiChu;
  String? tinhTrangXuLy;
  String? maMayXuLy;

  LinkYeuCauMayChiTietModel({
    required this.chiTietId,
    this.yeuCauId,
    this.loaiMay,
    this.maMay,
    this.hangMay,
    this.tanSuatSuDung,
    this.donGia,
    this.tinhTrang,
    this.soThangKhauHao,
    this.soLuong,
    this.thanhTienThang,
    this.ghiChu,
    this.tinhTrangXuLy,
    this.maMayXuLy,
  });

  Map<String, dynamic> toMap() => {
        'chiTietId': chiTietId,
        'yeuCauId': yeuCauId,
        'loaiMay': loaiMay,
        'maMay': maMay,
        'hangMay': hangMay,
        'tanSuatSuDung': tanSuatSuDung,
        'donGia': donGia,
        'tinhTrang': tinhTrang,
        'soThangKhauHao': soThangKhauHao,
        'soLuong': soLuong,
        'thanhTienThang': thanhTienThang,
        'ghiChu': ghiChu,
        'tinhTrangXuLy': tinhTrangXuLy,
        'maMayXuLy': maMayXuLy,
      };

  factory LinkYeuCauMayChiTietModel.fromMap(Map<String, dynamic> map) {
    double? parseDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    int? parseInt(dynamic v) => v == null ? null : int.tryParse(v.toString());

    return LinkYeuCauMayChiTietModel(
      chiTietId: map['chiTietId'],
      yeuCauId: map['yeuCauId'],
      loaiMay: map['loaiMay'],
      maMay: map['maMay'],
      hangMay: map['hangMay'],
      tanSuatSuDung: map['tanSuatSuDung'],
      donGia: parseInt(map['donGia']),
      tinhTrang: parseDouble(map['tinhTrang']),
      soThangKhauHao: parseInt(map['soThangKhauHao']),
      soLuong: parseInt(map['soLuong']),
      thanhTienThang: parseInt(map['thanhTienThang']),
      ghiChu: map['ghiChu'],
      tinhTrangXuLy: map['tinhTrangXuLy'],
      maMayXuLy: map['maMayXuLy'],
    );
  }
}
class LinkDanhMucMayModel {
  final String danhMucId;
  String? loaiMay;
  String? maMay;
  String? hangMay;

  LinkDanhMucMayModel({
    required this.danhMucId,
    this.loaiMay,
    this.maMay,
    this.hangMay,
  });

  Map<String, dynamic> toMap() => {
        'danhMucId': danhMucId,
        'loaiMay': loaiMay,
        'maMay': maMay,
        'hangMay': hangMay,
      };

  factory LinkDanhMucMayModel.fromMap(Map<String, dynamic> map) {
    return LinkDanhMucMayModel(
      danhMucId: map['danhMucId'],
      loaiMay: map['loaiMay'],
      maMay: map['maMay'],
      hangMay: map['hangMay'],
    );
  }
}
class LichCNkhuVucModel {
  final String uid;
  String? khuVuc;
  LichCNkhuVucModel({required this.uid, this.khuVuc});
  Map<String, dynamic> toMap() => {'uid': uid, 'khuVuc': khuVuc};
  factory LichCNkhuVucModel.fromMap(Map<String, dynamic> map) {
    return LichCNkhuVucModel(uid: map['uid'], khuVuc: map['khuVuc']);
  }
}

class LichCNhangMucModel {
  final String uid;
  String? doiTuong;
  LichCNhangMucModel({required this.uid, this.doiTuong});
  Map<String, dynamic> toMap() => {'uid': uid, 'doiTuong': doiTuong};
  factory LichCNhangMucModel.fromMap(Map<String, dynamic> map) {
    return LichCNhangMucModel(uid: map['uid'], doiTuong: map['doiTuong']);
  }
}

class LichCNkyThuatModel {
  final String uid;
  String? congViec;
  LichCNkyThuatModel({required this.uid, this.congViec});
  Map<String, dynamic> toMap() => {'uid': uid, 'congViec': congViec};
  factory LichCNkyThuatModel.fromMap(Map<String, dynamic> map) {
    return LichCNkyThuatModel(uid: map['uid'], congViec: map['congViec']);
  }
}

class LichCNtinhChatModel {
  final String uid;
  String? tinhChat;
  LichCNtinhChatModel({required this.uid, this.tinhChat});
  Map<String, dynamic> toMap() => {'uid': uid, 'tinhChat': tinhChat};
  factory LichCNtinhChatModel.fromMap(Map<String, dynamic> map) {
    return LichCNtinhChatModel(uid: map['uid'], tinhChat: map['tinhChat']);
  }
}

class LichCNtangToaModel {
  final String uid;
  String? boPhan;
  String? tenGoi;
  String? phanLoai;
  LichCNtangToaModel({required this.uid, this.boPhan, this.tenGoi, this.phanLoai});
  Map<String, dynamic> toMap() => {'uid': uid, 'boPhan': boPhan, 'tenGoi': tenGoi, 'phanLoai': phanLoai};
  factory LichCNtangToaModel.fromMap(Map<String, dynamic> map) {
    return LichCNtangToaModel(uid: map['uid'], boPhan: map['boPhan'], tenGoi: map['tenGoi'], phanLoai: map['phanLoai']);
  }
}

class LichCNchiTietModel {
  final String uid;
  String? nguoiDung;
  String? ngay;
  String? gio;
  String? lichId;
  String? boPhan;
  String? viTri;
  String? thap;
  String? tang;
  int? soPhut;
  String? khuVuc;
  String? doiTuong;
  String? congViec;
  String? tinhChat;
  LichCNchiTietModel({required this.uid, this.nguoiDung, this.ngay, this.gio, this.lichId, this.boPhan, this.viTri, this.thap, this.tang, this.soPhut, this.khuVuc, this.doiTuong, this.congViec, this.tinhChat});
  Map<String, dynamic> toMap() => {'uid': uid, 'nguoiDung': nguoiDung, 'ngay': ngay, 'gio': gio, 'lichId': lichId, 'boPhan': boPhan, 'viTri': viTri, 'thap': thap, 'tang': tang, 'soPhut': soPhut, 'khuVuc': khuVuc, 'doiTuong': doiTuong, 'congViec': congViec, 'tinhChat': tinhChat};
  factory LichCNchiTietModel.fromMap(Map<String, dynamic> map) {
    return LichCNchiTietModel(uid: map['uid'], nguoiDung: map['nguoiDung'], ngay: map['ngay'], gio: map['gio'], lichId: map['lichId'], boPhan: map['boPhan'], viTri: map['viTri'], thap: map['thap'], tang: map['tang'], soPhut: map['soPhut'], khuVuc: map['khuVuc'], doiTuong: map['doiTuong'], congViec: map['congViec'], tinhChat: map['tinhChat']);
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

  static const String chamCongTable = 'ChamCong';
 static const String chamCongGioTable = 'ChamCongGio';
 static const String chamCongLSTable = 'ChamCongLS';
 static const String chamCongCNThangTable = 'ChamCongCNThang';
   static const String chamCongVangNghiTcaTable = 'ChamCongVangNghiTca';
static const String imcDashboardTable = 'IMCDashboard';
static const String imcFAQTable = 'IMCFAQ';
static const String imcDocumentTable = 'IMCDocument';
static const String imcReportTable = 'IMCReport';
static const String imcProjectTable = 'IMCProject';
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
  static const String khuVucKhoChiTietTable = 'khuvuckhochitiet';
  static const String gocleanCongViecTable = 'GoClean_CongViec';
  static const String gocleanTaiKhoanTable = 'GoClean_TaiKhoan';
  static const String gocleanYeuCauTable = 'GoClean_YeuCau';
  static const String khachHangTable = 'KhachHang';
  static const String khachHangContactTable = 'KhachHangContact';
  static const String linkHopDongTable = 'LinkHopDong';
 static const String linkVatTuTable = 'LinkVatTu';
 static const String linkDinhKyTable = 'LinkDinhKy';
 static const String linkLeTetTCTable = 'LinkLeTetTC';
 static const String linkPhuCapTable = 'LinkPhuCap';
 static const String linkNgoaiGiaoTable = 'LinkNgoaiGiao';
 static const String linkMayMocTable = 'LinkMayMoc';
 static const String linkLuongTable = 'LinkLuong';
  static const String linkYeuCauMayTable = 'LinkYeuCauMay';
   static const String linkYeuCauMayChiTietTable = 'LinkYeuCauMayChiTiet';
    static const String linkDanhMucMayTable = 'LinkDanhMucMay';
    static const String lichCNkhuVucTable = 'LichCNkhuVuc';
static const String lichCNhangMucTable = 'LichCNhangMuc';
static const String lichCNkyThuatTable = 'LichCNkyThuat';
static const String lichCNtinhChatTable = 'LichCNtinhChat';
static const String lichCNtangToaTable = 'LichCNtangToa';
static const String lichCNchiTietTable = 'LichCNchiTiet';

static const String createLichCNkhuVucTable = '''
  CREATE TABLE $lichCNkhuVucTable (
    uid VARCHAR(100) PRIMARY KEY,
    khuVuc VARCHAR(100)
  )
''';

static const String createLichCNhangMucTable = '''
  CREATE TABLE $lichCNhangMucTable (
    uid VARCHAR(100) PRIMARY KEY,
    doiTuong VARCHAR(100)
  )
''';

static const String createLichCNkyThuatTable = '''
  CREATE TABLE $lichCNkyThuatTable (
    uid VARCHAR(100) PRIMARY KEY,
    congViec VARCHAR(100)
  )
''';

static const String createLichCNtinhChatTable = '''
  CREATE TABLE $lichCNtinhChatTable (
    uid VARCHAR(100) PRIMARY KEY,
    tinhChat VARCHAR(100)
  )
''';

static const String createLichCNtangToaTable = '''
  CREATE TABLE $lichCNtangToaTable (
    uid VARCHAR(100) PRIMARY KEY,
    boPhan VARCHAR(100),
    tenGoi VARCHAR(100),
    phanLoai VARCHAR(100)
  )
''';

static const String createLichCNchiTietTable = '''
  CREATE TABLE $lichCNchiTietTable (
    uid VARCHAR(100) PRIMARY KEY,
    nguoiDung VARCHAR(100),
    ngay DATE,
    gio TIME,
    lichId VARCHAR(100),
    boPhan VARCHAR(255),
    viTri VARCHAR(100),
    thap VARCHAR(100),
    tang VARCHAR(100),
    soPhut INT,
    khuVuc VARCHAR(100),
    doiTuong VARCHAR(100),
    congViec VARCHAR(100),
    tinhChat VARCHAR(100)
  )
''';
  static const String createLinkYeuCauMayTable = '''
    CREATE TABLE $linkYeuCauMayTable (
      yeuCauId VARCHAR(100) PRIMARY KEY,
      nguoiTao VARCHAR(100),
      ngay DATE,
      gio TIME,
      hopDongId VARCHAR(100),
      phanLoai VARCHAR(100),
      tenHopDong TEXT,
      diaChi TEXT,
      moTa TEXT,
      trangThai VARCHAR(100),
      nguoiGuiCapNhat VARCHAR(100),
      duyetKdCapNhat VARCHAR(100),
      duyetKtCapNhat VARCHAR(100)
    )
  ''';
    static const String createLinkYeuCauMayChiTietTable = '''
    CREATE TABLE $linkYeuCauMayChiTietTable (
      chiTietId VARCHAR(100) PRIMARY KEY,
      yeuCauId VARCHAR(100),
      loaiMay VARCHAR(100),
      maMay VARCHAR(100),
      hangMay VARCHAR(100),
      tanSuatSuDung VARCHAR(100),
      donGia INT,
      tinhTrang FLOAT,
      soThangKhauHao INT,
      soLuong INT,
      thanhTienThang INT,
      ghiChu TEXT,
      tinhTrangXuLy VARCHAR(100),
      maMayXuLy TEXT,
      FOREIGN KEY (yeuCauId) REFERENCES LinkYeuCauMay(yeuCauId)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    )
  ''';
  static const String createLinkDanhMucMayTable = '''
    CREATE TABLE $linkDanhMucMayTable (
      danhMucId VARCHAR(100) PRIMARY KEY,
      loaiMay VARCHAR(100),
      maMay VARCHAR(100),
      hangMay VARCHAR(100)
    )
  ''';
 static const String createLinkHopDongTable = '''
   CREATE TABLE $linkHopDongTable (
     uid VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     vungMien VARCHAR(255),
     ngayCapNhatCuoi DATE,
     maKeToan VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     trangThai VARCHAR(255),
     tenHopDong TEXT,
     diaChi TEXT,
     loaiHinh VARCHAR(255),
     congNhanHopDong DOUBLE,
     congNhanHDTang DOUBLE,
     congNhanHDGiam DOUBLE,
     congNhanDuocCo DOUBLE,
     giamSatCoDinh DOUBLE,
     doanhThuCu INT,
     comCu INT,
     comCu10phantram INT,
     comKHThucNhan INT,
     comGiam INT,
     comTangKhongThue INT,
     comTangTinhThue INT,
     doanhThuTangCNGia INT,
     doanhThuGiamCNGia INT,
     ghiChuHopDong TEXT,
     thoiHanHopDong INT,
     thoiHanBatDau DATE,
     thoiHanKetthuc DATE,
     soHopDong TEXT,
     doanhThuDangThucHien INT,
     doanhThuXuatHoaDon INT,
     doanhThuChenhLech INT,
     comMoi INT,
     phanTramThueMoi INT,
     comThucNhan INT,
     comTenKhachHang TEXT,
     chiPhiGiamSat INT,
     chiPhiVatLieu INT,
     chiPhiCVDinhKy INT,
     chiPhiLeTetTCa INT,
     chiPhiPhuCap INT,
     chiPhiNgoaiGiao INT,
     chiPhiMayMoc INT,
     chiPhiLuong INT,
     giaTriConLai INT,
     netCN INT,
     giaNetCN INT,
     netVung TEXT,
     chenhLechGia INT,
     chenhLechTong INT,
     daoHanHopDong VARCHAR(255),
     congViecCanGiaiQuyet TEXT,
     congNhanCa1 TEXT,
     congNhanCa2 TEXT,
     congNhanCa3 TEXT,
     congNhanCaHC TEXT,
     congNhanCaKhac TEXT,
     congNhanGhiChuBoTriNhanSu TEXT,
     fileHopDong TEXT
   )
 ''';

 static const String createLinkVatTuTable = '''
   CREATE TABLE $linkVatTuTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     danhMucVatTuTieuHao TEXT,
     nhanHieu TEXT,
     quyCach TEXT,
     donViTinh TEXT,
     donGiaCapKhachHang INT,
     soLuong DOUBLE,
     thanhTien INT
   )
 ''';

 static const String createLinkDinhKyTable = '''
   CREATE TABLE $linkDinhKyTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     danhMucCongViec VARCHAR(255),
     chiTietCongViec VARCHAR(255),
     tongTienTrenLanThucHien INT,
     tanSuatThucHienTrenThang DOUBLE,
     donGiaTrenThang INT,
     soLuong DOUBLE,
     thanhTien INT,
     ghiChu TEXT
   )
 ''';

 static const String createLinkLeTetTCTable = '''
   CREATE TABLE $linkLeTetTCTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     danhMucCongViec TEXT,
     chiTietCongViec TEXT,
     tanSuatTrenLan TEXT,
     donViTinh TEXT,
     donGia INT,
     soLuongNhanVien DOUBLE,
     thoiGianCungCapDVT DOUBLE,
     phanBoTrenThang DOUBLE,
     thanhTienTrenThang INT,
     ghiChu TEXT
   )
 ''';

 static const String createLinkPhuCapTable = '''
   CREATE TABLE $linkPhuCapTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     danhMucCongViec TEXT,
     chiTietCongViec TEXT,
     tanSuatTrenLan TEXT,
     donViTinh TEXT,
     donGia INT,
     soLuongNhanVien DOUBLE,
     thoiGianCungCapDVT DOUBLE,
     phanBoTrenThang DOUBLE,
     thanhTienTrenThang INT,
     ghiChu TEXT
   )
 ''';

 static const String createLinkNgoaiGiaoTable = '''
   CREATE TABLE $linkNgoaiGiaoTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     danhMuc TEXT,
     noiDungChiTiet TEXT,
     tanSuat TEXT,
     donViTinh TEXT,
     donGia INT,
     soLuong DOUBLE,
     thoiGianCungCapDVT DOUBLE,
     phanBoTrenThang DOUBLE,
     thanhTienTrenThang INT,
     ghiChu TEXT
   )
 ''';

 static const String createLinkMayMocTable = '''
   CREATE TABLE $linkMayMocTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     loaiMay TEXT,
     tenMay TEXT,
     hangSanXuat TEXT,
     tanSuat TEXT,
     donGiaMay INT,
     tinhTrangThietBi DOUBLE,
     khauHao INT,
     thanhTienMay INT,
     soLuongCap INT,
     thanhTienThang INT,
     ghiChu TEXT
   )
 ''';

 static const String createLinkLuongTable = '''
   CREATE TABLE $linkLuongTable (
     uid VARCHAR(255),
     hopDongID VARCHAR(255),
     thang DATE,
     nguoiTao VARCHAR(255),
     maKinhDoanh VARCHAR(255),
     hangMuc TEXT,
     moTa TEXT,
     donGia INT,
     soLuong DOUBLE,
     thanhTien INT
   )
 ''';

static const String createKhachHangContactTable = '''
  CREATE TABLE $khachHangContactTable (
    uid VARCHAR(255),
    boPhan TEXT,
    hinhAnh TEXT,
    nguoiDung VARCHAR(255),
    chiaSe TEXT,
    ngayTao DATE,
    ngayCapNhat DATE,
    hoSoYeuCau TEXT,
    hoTen VARCHAR(255),
    gioiTinh VARCHAR(255),
    chucDanh VARCHAR(255),
    tinhTrang VARCHAR(255),
    chucNang VARCHAR(255),
    thoiGianLamViec TEXT,
    soDienThoai VARCHAR(255),
    email VARCHAR(255),
    soThich TEXT,
    khongThich TEXT,
    tinhCach TEXT,
    yeuCauRiengVeDV TEXT,
    gioLam TEXT,
    nguyenTac TEXT, 
    kyVong TEXT,
    soDienThoai2 VARCHAR(255),
    sinhNhat DATE,
    diaChi TEXT,
    tenNick VARCHAR(255),
    nguonGoc VARCHAR(255)
  )
''';
static const String createKhachHangTable = '''
  CREATE TABLE $khachHangTable (
    uid VARCHAR(100),
    nguoiDung VARCHAR(100),
    chiaSe TEXT,
    danhDau VARCHAR(100),
    vungMien VARCHAR(100),
    phanLoai VARCHAR(100),
    loaiHinh VARCHAR(100),
    loaiCongTrinh VARCHAR(100),
    maBP VARCHAR(100),
    maKT VARCHAR(100),
    maKD VARCHAR(100),
    trangThaiHopDong VARCHAR(100),
    tenDuAn TEXT,
    tenKyThuat TEXT,
    tenRutGon TEXT,
    tenVatTu TEXT,
    giamSat VARCHAR(100),
    qldv VARCHAR(100),
    ghiChu TEXT,
    diaChi TEXT,
    diaChiVanPhong TEXT,
    sdtDuAn VARCHAR(100),
    nhanSuTheoHopDong DOUBLE,
    nhanSuDuocCo DOUBLE,
    hinhAnh TEXT,
    maSoThue VARCHAR(100),
    soDienThoai VARCHAR(100),
    fax VARCHAR(100),
    website TEXT,
    email TEXT,
    soTaiKhoan TEXT,
    nganHang TEXT,
    ngayCapNhatCuoi DATE,
    ngayKhoiTao DATE,
    loaiMuaHang VARCHAR(100),
    tinhThanh VARCHAR(100),
    quanHuyen VARCHAR(100),
    phuongXa VARCHAR(100),
    kenhTiepCan VARCHAR(100),
    duKienTrienKhai TEXT,
    tiemNangDVTM TEXT,
    yeuCauNhanSu TEXT,
    cachThucTuyen TEXT,
    mucLuongTuyen TEXT,
    luongBP TEXT
  )
''';
  static const String createGoCleanYeuCauTable = '''
    CREATE TABLE $gocleanYeuCauTable (
      GiaoViecID VARCHAR(100),
      NguoiTao VARCHAR(100),
      NguoiNghiemThu TEXT,
      DiaDiem TEXT,
      DiaChi TEXT,
      DinhVi VARCHAR(100),
      LapLai VARCHAR(100),
      NgayBatDau DATE,
      NgayKetThuc DATE,
      HinhThucNghiemThu VARCHAR(100),
      MoTaCongViec TEXT,
      SoNguoiThucHien INT,
      KhuVucThucHien TEXT,
      KhoiLuongCongViec INT,
      YeuCauCongViec TEXT,
      ThoiGianBatDau TIME,
      ThoiGianKetThuc TEXT, 
      LoaiMaySuDung TEXT,
      CongCuSuDung TEXT,
      HoaChatSuDung TEXT,
      GhiChu TEXT,
      XacNhan TEXT,
      ChiDinh VARCHAR(100),
      HuongDan TEXT,
      NhomThucHien VARCHAR(255),
      CaNhanThucHien VARCHAR(100),
      ListNguoiThucHien TEXT
    )
  ''';
  static const String createGoCleanTaiKhoanTable = '''
    CREATE TABLE $gocleanTaiKhoanTable (
      UID VARCHAR(100),
      TaiKhoan VARCHAR(100),
      PhanLoai VARCHAR(100),
      DinhVi VARCHAR(100),
      LoaiDinhVi VARCHAR(100),
      SDT VARCHAR(100),
      Email VARCHAR(100),
      DiaDiem TEXT,
      DiaChi TEXT,
      HinhAnh TEXT,
      TrangThai VARCHAR(100),
      Nhom VARCHAR(100),
      Admin VARCHAR(100)
    )
  ''';
  static const String createGoCleanCongViecTable = '''
    CREATE TABLE $gocleanCongViecTable (
      LichLamViecID VARCHAR(100),
      GiaoViecID VARCHAR(100),
      Ngay DATE,
      NguoiThucHien VARCHAR(100),
      XacNhan VARCHAR(100),
      QRcode VARCHAR(100),
      MocBatDau TIME,
      HinhAnhTruoc TEXT,
      MocKetThuc TIME,
      HinhAnhSau TEXT,
      ThucHienDanhGia INT,
      MoTaThucHien TEXT,
      KhachHang VARCHAR(100),
      KhachHangDanhGia INT,
      ThoiGianDanhGia TIME,
      KhachHangMoTa TEXT,
      KhachHangChupAnh TEXT,
      TrangThai VARCHAR(100)
    )
  ''';
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
  static const String createKhuVucKhoChiTietTable = '''
  CREATE TABLE $khuVucKhoChiTietTable (
    chiTietID TEXT,
    khuVucKhoID TEXT,
    tang TEXT,
    tangSize TEXT,
    phong TEXT,
    ke TEXT,
    tangKe TEXT,
    gio TEXT,
    noiDung TEXT,
    viTri TEXT,
    dungTich INTEGER
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