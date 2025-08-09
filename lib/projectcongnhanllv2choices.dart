// projectcongnhanllv2choices.dart
import 'package:flutter/material.dart';

/// Ordered display for Loại làm sạch chính:
/// First show these (popular), then the rest A>Z.
const List<String> kPopularMainTypes = [
  'Sàn',
  'Bồn cầu',
  'Bậc thang',
  'Chậu rửa',
  'Kính',
  'Cửa',
];

const List<String> kAllMainTypesAZ = [
  'Bậc thang',
  'Bàn',
  'Ban công',
  'Barie',
  'Biển báo',
  'Bình cứu hỏa',
  'Bồn cầu',
  'Bồn tiểu',
  'Bốt bảo vệ',
  'Bục',
  'Chấn song',
  'Chậu cây',
  'Chậu rửa',
  'Chớp kính',
  'Cốc chén',
  'Cống',
  'Cổng',
  'Cột',
  'Cửa',
  'Cửa sổ',
  'Đèn báo',
  'Đường ống',
  'Gạch ốp',
  'Ghế',
  'Gờ',
  'Gương',
  'Hố ga',
  'Khung',
  'Kính',
  'Lan can',
  'Mái',
  'Mạng nhện',
  'Ổ điện',
  'Ốp chân tường',
  'Ốp tường',
  'Quầy',
  'Rèm',
  'Sàn',
  'Thảm',
  'Thang máy',
  'Thùng rác',
  'Tiểu cảnh',
  'Trần',
  'Tủ',
  'Vách ngăn',
  'Vòi',
];

/// Build the final ordered list: popular first (no dupes), then the rest A>Z.
List<String> buildOrderedMainTypes() {
  final popularSet = kPopularMainTypes.toSet();
  final rest = kAllMainTypesAZ
      .where((e) => !popularSet.contains(e))
      .toList()
    ..sort((a, b) => a.compareTo(b));
  return [...kPopularMainTypes, ...rest];
}

/// Map of main type -> list of materials (Chất liệu).
/// Only these keys require a material selection; others show no material dropdown.
const Map<String, List<String>> kMaterialOptionsByMainType = {
  'Bậc thang': [
    'xi măng',
    'gạch men',
    'nhựa',
    'sắt (quét sơn )',
    'đá granito',
    'sơn eboxy',
  ],
  'Cửa': [
    'gỗ',
    'Sắt (phun sơn)',
    'khung nhôm kính',
    'kính',
    'inox',
  ],
  'Gạch ốp': [
    'men sứ',
    'đá marble',
    'đá granite',
    'amilu',
  ],
  'Bàn': [
    'gỗ công nghiệp',
    'inox',
    'dán focmeca',
    'gỗ thịt',
  ],
  'Gương': [
    'Gương',
  ],
  'Sàn': [
    'gạch men',
    'ceramic',
    'gạch đỏ',
    'xi măng',
    'sơn PU',
    'granito',
    'granite tự nhiên',
    'granite nhân tạo',
  ],
  'Thảm': [
    'Gai',
    'len',
    'nhựa',
  ],
  'Rèm': [
    'vải',
    'nhựa',
    'gỗ',
  ],
};

const List<String> kUnits = ['m2', 'mét', 'cái', 'lít'];

/// Simple pill-like chip for single-choice clouds
class SingleChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SingleChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey[300];
    final textColor = selected ? Colors.white : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
