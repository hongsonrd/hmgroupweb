import 'package:flutter/material.dart';
import 'table_models.dart';

// Simple confirmation dialog for work requests
void showConfirmationDialog(BuildContext context, GoCleanYeuCauModel request) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Xác nhận yêu cầu',
        style: TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn muốn xác nhận yêu cầu công việc này?',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'ID: ${request.giaoViecID ?? "N/A"}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          SizedBox(height: 4),
          Text(
            'Mô tả: ${request.moTaCongViec ?? "Không có mô tả"}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Text(
            'Địa điểm: ${request.diaDiem ?? "N/A"}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (request.ngayBatDau != null) SizedBox(height: 4),
          if (request.ngayBatDau != null)
            Text(
              'Thời gian: ${request.ngayBatDau!.day}/${request.ngayBatDau!.month}/${request.ngayBatDau!.year} - ${request.ngayKetThuc != null ? "${request.ngayKetThuc!.day}/${request.ngayKetThuc!.month}/${request.ngayKetThuc!.year}" : "N/A"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            // Simply close the dialog and show a message
            Navigator.pop(context);
            
            // Show a message that confirmation was sent
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã gửi xác nhận yêu cầu'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
          ),
          child: Text('Xác nhận'),
        ),
      ],
    ),
  );
}

// This function can be used in other files to get the status color
Color getStatusColor(String? status) {
  if (status == null) return Colors.grey;
  
  switch (status.toLowerCase()) {
    case 'đã hoàn thành':
      return Colors.green;
    case 'đang thực hiện':
      return Colors.orange;
    case 'chờ xác nhận':
      return Colors.purple;
    case 'chưa bắt đầu':
      return Colors.blue;
    case 'hủy bỏ':
      return Colors.red;
    default:
      return Colors.grey;
  }
}