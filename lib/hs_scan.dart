import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'user_credentials.dart';
import 'location_provider.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
class HSScanScreen extends StatefulWidget {
  final String? username;
  
  const HSScanScreen({Key? key, this.username}) : super(key: key);
  
  @override
  _HSScanScreenState createState() => _HSScanScreenState();
}

class _HSScanScreenState extends State<HSScanScreen> {
  bool _isScanning = true;
  String _orderNumber = '';
  DonHangModel? _orderDetails;
  List<ChiTietDonModel> _orderItems = [];
  final DBHelper _dbHelper = DBHelper();
  bool _hasError = false;
  String _errorMessage = '';
  MobileScannerController? _scannerController;
  List<Map<String, dynamic>> _deliveryHistory = [];
  // List of authorized users who can confirm delivery
  final List<String> _authorizedUsers = ['nvthunghiem', 'hm.tason', 'hm.anhviet','hm.manhha','hm.kimdung','hm.phiminh'];
  
  @override
  void initState() {
    super.initState();
    _initializeScanner();
    // Initialize location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
  Future<void> _fetchOrderDetails(String soPhieu) async {
    try {
      final order = await _dbHelper.getDonHangBySoPhieu(soPhieu);
      
      if (order != null) {
        final items = await _dbHelper.getChiTietDonBySoPhieu(soPhieu);
        // Fetch delivery history
        final history = await _dbHelper.getGiaoHangBySoPhieu(soPhieu);
        
        setState(() {
          _orderDetails = order;
          _orderItems = items;
          _deliveryHistory = history;
          _hasError = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _orderDetails = null;
          _orderItems = [];
          _deliveryHistory = []; 
          _hasError = true;
          _errorMessage = 'Không tìm thấy đơn hàng với mã: $soPhieu';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Lỗi khi tìm kiếm đơn hàng: ${e.toString()}';
      });
    }
  }
  Future<void> _requestLocationPermission() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.fetchLocation();
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.first;

    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Stop scanning temporarily
    setState(() {
      _isScanning = false;
      _orderNumber = code;
    });

    // Fetch order details
    await _fetchOrderDetails(code);
  }

  void _resetScan() {
    setState(() {
      _isScanning = true;
      _orderNumber = '';
      _orderDetails = null;
      _orderItems = [];
      _deliveryHistory = []; 
      _hasError = false;
      _errorMessage = '';
    });
  }

  bool _isUserAuthorized() {
  // First check the username passed to the widget
  if (widget.username != null && widget.username!.isNotEmpty) {
    return _authorizedUsers.contains(widget.username);
  }
  
  // Fall back to UserCredentials provider if no username was passed
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  return _authorizedUsers.contains(userCredentials.username);
}

  // Show delivery confirmation dialog
  Future<void> _showDeliveryConfirmationDialog(BuildContext context) async {
  // Get username either from widget parameter or from provider
  String username = '';
  if (widget.username != null && widget.username!.isNotEmpty) {
    username = widget.username!;
  } else {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    username = userCredentials.username;
  }
  
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);
  final TextEditingController _notesController = TextEditingController();
  File? _image1, _image2;
  final _imagePicker = ImagePicker();
  
  // Ensure we have the latest location
  await locationProvider.fetchLocation();
  final currentLocation = locationProvider.locationData;
  String locationStr = '';
  
  if (currentLocation != null && 
      currentLocation.latitude != null && 
      currentLocation.longitude != null) {
    locationStr = '${currentLocation.latitude},${currentLocation.longitude}';
  }
    
    Future<File?> _pickImage() async {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    }
    
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Xác nhận giao hàng'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đơn hàng: ${_orderDetails?.soPhieu ?? ''}'),
                    SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationProvider.address.isEmpty ? 
                              'Đang xác định vị trí...' : 
                              locationProvider.address,
                            style: TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    
                    SizedBox(height: 16),
                    
                    Text('Hình ảnh giao hàng (bắt buộc):'),
                    SizedBox(height: 8),
                    
                    GestureDetector(
                      onTap: () async {
                        final file = await _pickImage();
                        if (file != null) {
                          setState(() {
                            _image1 = file;
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _image1 != null
                            ? Image.file(_image1!, fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Chụp ảnh 1'),
                                ],
                              ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    Text('Hình ảnh giao hàng (tùy chọn):'),
                    SizedBox(height: 8),
                    
                    GestureDetector(
                      onTap: () async {
                        final file = await _pickImage();
                        if (file != null) {
                          setState(() {
                            _image2 = file;
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _image2 != null
                            ? Image.file(_image2!, fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Chụp ảnh 2 (tùy chọn)'),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
  ),
  child: Text('Xác nhận'),
  onPressed: _image1 == null
    ? null
    : () async {
        // Store context reference and close dialog first
        Navigator.of(context).pop();
        
        // Show loading indicator with a separate BuildContext
        BuildContext? loadingContext;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            loadingContext = ctx;
            return Center(child: CircularProgressIndicator());
          },
        );
        
        try {
          // Get username either from widget parameter or from provider
          String username = '';
          if (widget.username != null && widget.username!.isNotEmpty) {
            username = widget.username!;
          } else {
            final userCredentials = Provider.of<UserCredentials>(context, listen: false);
            username = userCredentials.username;
          }
          
          await _submitDeliveryConfirmation(
            _orderDetails!.soPhieu!,
            username,
            _notesController.text,
            _image1!,
            _image2,
            locationStr,
          );
          
          // Close loading dialog if it's still showing
          if (loadingContext != null && Navigator.canPop(loadingContext!)) {
            Navigator.of(loadingContext!).pop();
          }
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xác nhận giao hàng thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh order details to show updated delivery history
          await _fetchOrderDetails(_orderDetails!.soPhieu!);
          
        } catch (e) {
          // Close loading dialog if it's still showing
          if (loadingContext != null && Navigator.canPop(loadingContext!)) {
            Navigator.of(loadingContext!).pop();
          }
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
),
              ],
            );
          },
        );
      },
    );
  }
  
  // Enhanced _submitDeliveryConfirmation function with detailed logging
Future<void> _submitDeliveryConfirmation(
  String soPhieu,
  String nguoiGiao,
  String ghiChu,
  File image1,
  File? image2,
  String dinhVi,
) async {
  print('======= STARTING DELIVERY SUBMISSION =======');
  print('SoPhieu: $soPhieu');
  print('NguoiGiao: $nguoiGiao');
  print('DinhVi: $dinhVi');
  print('Image1 exists: ${image1.existsSync()}');
  print('Image1 path: ${image1.path}');
  print('Image1 size: ${await image1.length()} bytes');
  if (image2 != null) {
    print('Image2 exists: ${image2.existsSync()}');
    print('Image2 path: ${image2.path}');
    print('Image2 size: ${await image2.length()} bytes');
  } else {
    print('Image2: Not provided');
  }
  
  final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelgiaohangmoi');
  print('Submitting to URL: $url');
  
  // Create delivery data
  final uuid = Uuid();
  final uid = uuid.v4();
  print('Generated UID: $uid');
  
  final now = DateTime.now();
  final ngay = DateFormat('yyyy-MM-dd').format(now);
  final gio = DateFormat('HH:mm:ss').format(now);
  print('Formatted date: $ngay, time: $gio');
  
  try {
    var request = http.MultipartRequest('POST', url);
    
    // Add text fields
    request.fields['UID'] = uid;
    request.fields['SoPhieu'] = soPhieu;
    request.fields['NguoiGiao'] = nguoiGiao;
    request.fields['Ngay'] = ngay;
    request.fields['Gio'] = gio;
    request.fields['GhiChu'] = ghiChu;
    request.fields['DinhVi'] = dinhVi;
    
    print('Added form fields to request');
    
    // Add image1 (required)
    try {
      final image1File = await http.MultipartFile.fromPath(
        'HinhAnh',
        image1.path,
      );
      print('Created MultipartFile for image1: ${image1File.length} bytes, filename: ${image1File.filename}');
      request.files.add(image1File);
      print('Added image1 to request');
    } catch (e) {
      print('ERROR adding image1: $e');
      throw Exception('Failed to process first image: $e');
    }
    
    // Add image2 (optional)
    if (image2 != null) {
      try {
        final image2File = await http.MultipartFile.fromPath(
          'HinhAnh2',
          image2.path,
        );
        print('Created MultipartFile for image2: ${image2File.length} bytes, filename: ${image2File.filename}');
        request.files.add(image2File);
        print('Added image2 to request');
      } catch (e) {
        print('ERROR adding image2: $e');
        throw Exception('Failed to process second image: $e');
      }
    }
    
    print('Request fully prepared, sending...');
    print('Request fields: ${request.fields}');
    print('Request files count: ${request.files.length}');
    
    // Send request
    try {
      final streamedResponse = await request.send();
      print('Response status code: ${streamedResponse.statusCode}');
      print('Response headers: ${streamedResponse.headers}');
      
      final responseBody = await streamedResponse.stream.bytesToString();
      print('Response body: $responseBody');
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('Server error: ${streamedResponse.statusCode} - $responseBody');
      }
      
      print('Successfully submitted delivery confirmation');
      
      // Add delivery confirmation to local database
      try {
        await _dbHelper.insertGiaoHang({
          'UID': uid,
          'SoPhieu': soPhieu,
          'NguoiGiao': nguoiGiao,
          'Ngay': ngay,
          'Gio': gio,
          'GhiChu': ghiChu,
          'HinhAnh': 'uploaded', // Will be updated with server URL
          'HinhAnh2': image2 != null ? 'uploaded' : '', // Will be updated with server URL
          'DinhVi': dinhVi,
        });
        print('Saved delivery record to local database');
      } catch (e) {
        print('ERROR saving to local database: $e');
        // Continue even if local save fails
      }
      
    } catch (e) {
      print('ERROR during request: $e');
      throw Exception('Error sending request: $e');
    }
  } catch (e) {
    print('CRITICAL ERROR in submission: $e');
    throw Exception('Failed to submit delivery confirmation: $e');
  } finally {
    print('======= FINISHED DELIVERY SUBMISSION =======');
  }
}
  @override
  Widget build(BuildContext context) {
    // Define colors consistent with the app's theme
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    final Color buttonColor = Color(0xFF837826);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tra cứu đơn hàng' , style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [appBarTop, appBarBottom],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Scanner or Results area
          Expanded(
            child: _isScanning
                ? _buildScannerView()
                : _buildResultsView(),
          ),
          
          // Bottom buttons
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // QR scan button (always visible)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _resetScan,
                    icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: Text(
                      'Quét mã QR khác',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                // Delivery confirmation button (only for authorized users and when not scanning)
                if (!_isScanning && _orderDetails != null && _isUserAuthorized())
  SizedBox(width: 12),
  
if (!_isScanning && _orderDetails != null && _isUserAuthorized())
  Expanded(
    child: ElevatedButton.icon(
      onPressed: () => _showDeliveryConfirmationDialog(context),
      icon: Icon(Icons.local_shipping, color: Colors.white),
      label: Text(
        'Xác nhận giao hàng',
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeScanner,
                child: Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF837826),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Scanner
        _scannerController != null
            ? MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  print('Scanner error: $error');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Lỗi máy quét: ${error.toString()}',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _initializeScanner,
                          child: Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF837826),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            : Center(child: CircularProgressIndicator()),
        
        // Scan overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
          ),
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white.withOpacity(0.8),
                    size: 80,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Quét mã QR đơn hàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_orderDetails == null) {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order header card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'THÔNG TIN ĐƠN HÀNG',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF534b0d),
                    ),
                  ),
                ),
                Divider(thickness: 1),
                SizedBox(height: 8),
                _buildInfoRow('Số phiếu:', _orderDetails!.soPhieu ?? 'N/A'),
                _buildInfoRow('Ngày tạo:', _orderDetails!.ngay ?? 'N/A'),
                _buildInfoRow('Khách hàng:', _orderDetails!.tenKhachHang2 ?? 'N/A'),
                _buildInfoRow('Người tạo:', _orderDetails!.nguoiTao ?? 'N/A'),
                _buildInfoRow('Trạng thái:', _getStatusText(_orderDetails!.trangThai)),
                _buildInfoRow('Ghi chú:', _orderDetails!.ghiChu ?? 'N/A'),
              ],
            ),
          ),
        ),
        
        // Delivery history section - add this section
        if (_deliveryHistory.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            'LỊCH SỬ GIAO HÀNG',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF534b0d),
            ),
          ),
          SizedBox(height: 8),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _deliveryHistory.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final delivery = _deliveryHistory[index];
                final hasImage = delivery['HinhAnh'] != null && delivery['HinhAnh'].toString().startsWith('http');
                final hasImage2 = delivery['HinhAnh2'] != null && delivery['HinhAnh2'].toString().startsWith('http');
                
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${delivery['Ngay'] ?? 'N/A'} ${delivery['Gio'] ?? ''}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Text(
                        'Người giao: ${delivery['NguoiGiao'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  trailing: hasImage 
                      ? Icon(Icons.image, color: Colors.blue, size: 22)
                      : null,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  dense: true,
                  onTap: () => _showDeliveryDetails(context, delivery),
                );
              },
            ),
          ),
        ],
        
        SizedBox(height: 16),
        
        // Order items section (existing code)
        Text(
          'CHI TIẾT ĐƠN HÀNG',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF534b0d),
          ),
        ),
          SizedBox(height: 8),
          
          _orderItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Không có mặt hàng nào trong đơn',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              : Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _orderItems.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _orderItems[index];
                      return ListTile(
                        title: Text(
                          item.idHang ?? 'Sản phẩm không tên',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('Số lượng: ${item.soLuongYeuCau?.toString() ?? '0'} ${item.donViTinh ?? ''}'),
                          ],
                        ),
                        isThreeLine: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      );
                    },
                  ),
                ),
          
          // Location info (if available)
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              if (locationProvider.locationData != null && 
                  locationProvider.address.isNotEmpty) {
                return Card(
                  margin: EdgeInsets.only(top: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THÔNG TIN VỊ TRÍ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF534b0d),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationProvider.address,
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
  void _showDeliveryDetails(BuildContext context, Map<String, dynamic> delivery) {
  final hasImage = delivery['HinhAnh'] != null && delivery['HinhAnh'].toString().startsWith('http');
  final hasImage2 = delivery['HinhAnh2'] != null && delivery['HinhAnh2'].toString().startsWith('http');
  
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Text(
                      'CHI TIẾT GIAO HÀNG',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF534b0d),
                      ),
                    ),
                  ),
                  Divider(thickness: 1),
                  SizedBox(height: 12),
                  
                  // Delivery info
                  _buildInfoRow('Ngày giao:', delivery['Ngay'] ?? 'N/A'),
                  _buildInfoRow('Giờ giao:', delivery['Gio'] ?? 'N/A'),
                  _buildInfoRow('Người giao:', delivery['NguoiGiao'] ?? 'N/A'),
                  if (delivery['GhiChu'] != null && delivery['GhiChu'].toString().isNotEmpty)
                    _buildInfoRow('Ghi chú:', delivery['GhiChu']),
                  if (delivery['DinhVi'] != null && delivery['DinhVi'].toString().isNotEmpty)
                    _buildInfoRow('Vị trí:', delivery['DinhVi']),
                  
                  SizedBox(height: 16),
                  
                  // First image
                  if (hasImage) ...[
                    Text(
                      'Hình ảnh 1:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: delivery['HinhAnh'],
                        placeholder: (context, url) => Center(
                          child: Container(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareImage(delivery['HinhAnh']),
                        icon: Icon(Icons.share, size: 18),
                        label: Text('Chia sẻ' ,style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF837826),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Second image
                  if (hasImage2) ...[
                    Text(
                      'Hình ảnh 2:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: delivery['HinhAnh2'],
                        placeholder: (context, url) => Center(
                          child: Container(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareImage(delivery['HinhAnh2']),
                        icon: Icon(Icons.share, size: 18),
                        label: Text('Chia sẻ', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF837826),
                        ),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 16),
                  
                  // Close button
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Đóng', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
Future<void> _shareImage(String imageUrl) async {
  try {
    await Share.share(
      'Hình ảnh giao hàng: $imageUrl',
      subject: 'Chia sẻ hình ảnh giao hàng',
    );
  } catch (e) {
    print('Error sharing image: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi chia sẻ hình ảnh: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    if (status == null) return 'Không xác định';
    
    switch (status) {
      case "0":
        return 'Đang xử lý';
      case "1":
        return 'Đã duyệt';
      case "2":
        return 'Đang giao hàng';
      case "3":
        return 'Hoàn thành';
      case "4":
        return 'Đã hủy';
      default:
        return status;
    }
  }
}