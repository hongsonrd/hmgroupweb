import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../user_state.dart';
import '../main.dart' show MainScreen;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}
class _WebViewScreenState extends State<WebViewScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  List<Map<String, dynamic>>? _filteredItems;
  
  final List<Map<String, dynamic>> gridData = [
{'icon': 'assets/timelogo.png', 'name': 'HM Time', 'link': 'https://www.appsheet.com/start/bd11e9cb-0d5c-423f-bead-3c07f1eae0a3','userAccess':[]},
{'icon': 'assets/homelogo.png', 'name': 'HM Home', 'link': 'https://www.appsheet.com/start/475f549e-63de-4071-947f-612f4612f377','userAccess':[]},
{'icon': 'assets/checklogo.png', 'name': 'HM Check', 'link': 'https://www.appsheet.com/start/38c43e28-1170-4234-95b7-3ea57358a3fa','userAccess':[]},
{'icon': 'assets/linklogo.png', 'name': 'HM Link', 'link': 'https://www.appsheet.com/start/28785d83-62f3-4ec6-8ddd-2780d413dfa7','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Thành', 'link': 'https://zalo.me/g/bawdga557','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Nguyễn Huyền', 'link': 'https://zalo.me/g/ewolpl197','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Lợi', 'link': 'https://zalo.me/g/wwcgsg503','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Bùi Huyền', 'link': 'https://zalo.me/g/iqwwbf431','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Thanh', 'link': 'https://zalo.me/g/dfhdid376','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Hạnh', 'link': 'https://zalo.me/g/xhblsr399','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Hùng', 'link': 'https://zalo.me/g/pzexka072','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Miền Trung', 'link': 'https://zalo.me/g/nvrkqe767','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA Miền Nam', 'link': 'https://zalo.me/g/nvrkqe767','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'OA QLDV', 'link': 'https://zalo.me/g/xbcalx122','userAccess':[]},
{'icon': 'assets/logokt.png', 'name': 'HM Kỹ thuật', 'link': 'https://www.appsheet.com/start/f2040b99-7558-4e2c-9e02-df100c83d8ce','userAccess':[]},
{'icon': 'assets/goodslogo.png', 'name': 'HM Goods', 'link': 'https://www.appsheet.com/start/a97dcdb4-806c-47ac-9277-714e392b2d1b','userAccess':[]},
{'icon': 'assets/hrlogo.png', 'name': 'HM HR', 'link': 'https://www.appsheet.com/start/adc9a180-6992-4dc3-84ee-9a57cfe70013','userAccess':[]},
{'icon': 'assets/officitylogo.png', 'name': 'HM Officity', 'link': 'https://www.appsheet.com/start/b52d2de9-e42f-40eb-ba6e-9fb5b15ba287','userAccess':[]},
{'icon': 'assets/oalogo.png', 'name': 'HM OA', 'link': 'https://www.appsheet.com/start/bbe6a3e9-e704-4fa6-a821-1264bb6e9c11?platform=desktop','userAccess':[]},
{'icon': 'assets/logo.png', 'name': 'Check lịch', 'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'Zalo Hoàn Mỹ', 'link': 'https://zalo.me/2746464448500686217','userAccess':[]},
{'icon': 'assets/fblogo.png', 'name': 'Facebook Hoàn Mỹ', 'link': 'https://www.facebook.com/Hoanmykleanco','userAccess':[]},
{'icon': 'assets/tiktoklogo.png', 'name': 'Tiktok Hoàn Mỹ', 'link': 'https://www.tiktok.com/@hoanmykleanco','userAccess':[]},
{'icon': 'assets/weblogo.png', 'name': 'Website Hoàn Mỹ', 'link': 'https://hoanmykleanco.com/','userAccess':[]},
{'icon': 'assets/iglogo.png', 'name': 'Instagram Hoàn Mỹ', 'link': 'https://www.instagram.com/hoanmykleanco/','userAccess':[]},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/c91ee3be-8d1d-4c6c-904b-c45e2a746227/page/p_4aim8v2qbd',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/c91ee3be-8d1d-4c6c-904b-c45e2a746227/page/p_els3diiled',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/bcf51011-8ed5-4af5-adec-44f5729a3a60/page/p_1ezjaa2oed',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/a5a93498-354d-4c34-9061-42ec08de5827/page/p_i155gan27c',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/0248fcb6-af01-44f2-a74b-f6d937ccaef8/page/p_cxdlxder3c',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/f53328f8-1927-49a1-a14c-047ad5f58809/page/p_12wwvq36dd',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/c91ee3be-8d1d-4c6c-904b-c45e2a746227/page/p_5q3z0tmyed',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/c91ee3be-8d1d-4c6c-904b-c45e2a746227/page/p_tqvp3guzed',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/9cfcfef1-9b0c-4c99-bef9-36529f5a0199/page/p_4aim8v2qbd',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/9cfcfef1-9b0c-4c99-bef9-36529f5a0199/page/p_els3diiled',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/7f2a81ef-87ac-4065-9a61-24dfcad9a4e2/page/p_1ezjaa2oed',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/f0e4814a-6c48-4b18-8eca-d886985ac8fb/page/p_i155gan27c',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/61ba35a3-5c46-439c-ac45-4bf7cf49ec60/page/p_cxdlxder3c',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/c645ff79-42e7-462a-aec9-a41cb572915b/page/p_12wwvq36dd',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/9cfcfef1-9b0c-4c99-bef9-36529f5a0199/page/p_5q3z0tmyed',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/9cfcfef1-9b0c-4c99-bef9-36529f5a0199/page/p_tqvp3guzed',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/ab54db60-a045-4b93-b0e4-a9a5036e55a5/page/p_4aim8v2qbd',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/ab54db60-a045-4b93-b0e4-a9a5036e55a5/page/p_els3diiled',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/8e25b78e-df5f-4769-aaf0-7993ea6bca02/page/p_1ezjaa2oed',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/062e9a2b-2257-41a2-b3bd-91b5eaa33a88/page/p_i155gan27c',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/2fbbf5a6-c089-4408-ba8c-cbdaa12b872c/page/p_cxdlxder3c',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/a9f459f7-2682-46f3-9410-b8affe9da3de/page/p_12wwvq36dd',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/ab54db60-a045-4b93-b0e4-a9a5036e55a5/page/p_5q3z0tmyed',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/ab54db60-a045-4b93-b0e4-a9a5036e55a5/page/p_tqvp3guzed',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/4f1a099d-0f68-488e-8497-5f41aaf2de00/page/p_4aim8v2qbd',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/4f1a099d-0f68-488e-8497-5f41aaf2de00/page/p_els3diiled',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/a0eb178a-442a-4819-9a7a-ed1014040660/page/p_1ezjaa2oed',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/0bbdb821-7dbb-4e5a-a07b-10c48ca8bdde/page/p_i155gan27c',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/78db5d81-8e22-486e-90c5-382bc88d23e3/page/p_cxdlxder3c',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/4c8acfca-eba9-40b5-b29e-6ce5820fc4d5/page/p_12wwvq36dd',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/4f1a099d-0f68-488e-8497-5f41aaf2de00/page/p_5q3z0tmyed',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/4f1a099d-0f68-488e-8497-5f41aaf2de00/page/p_tqvp3guzed',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/7a423b39-ab4a-4206-adeb-adf52a01a974/page/p_4aim8v2qbd',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/7a423b39-ab4a-4206-adeb-adf52a01a974/page/p_els3diiled',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/3c44e787-c2dd-4247-917d-2b62eec5f58e/page/p_1ezjaa2oed',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/c6d41b2f-aed4-40c5-9f8a-0184a62d8b31/page/p_i155gan27c',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/9dd30031-584c-4d76-b3d0-ff7663cff140/page/p_cxdlxder3c',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/d5f140ac-d41e-4b6f-ad88-e8f312579520/page/p_12wwvq36dd',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/7a423b39-ab4a-4206-adeb-adf52a01a974/page/p_5q3z0tmyed',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/7a423b39-ab4a-4206-adeb-adf52a01a974/page/p_tqvp3guzed',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/42269a8e-31d1-4384-a21f-b505efb9cb6f/page/p_4aim8v2qbd',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/42269a8e-31d1-4384-a21f-b505efb9cb6f/page/p_els3diiled',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/ba65a503-990b-4531-9be0-461094db8d3e/page/p_1ezjaa2oed',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/6bea48ae-d778-46b9-adea-22ac9d952b0a/page/p_i155gan27c',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/65ba86d3-f163-44e1-8042-e9cb05b35b1d/page/p_cxdlxder3c',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/ba0e4d6b-84be-47e3-afb8-a6864a0cf29f/page/p_12wwvq36dd',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/42269a8e-31d1-4384-a21f-b505efb9cb6f/page/p_5q3z0tmyed',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/42269a8e-31d1-4384-a21f-b505efb9cb6f/page/p_tqvp3guzed',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/9452ebe5-e2ef-4d8d-9686-bd02943eee27/page/p_4aim8v2qbd',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/9452ebe5-e2ef-4d8d-9686-bd02943eee27/page/p_els3diiled',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/07141eff-b13f-4c93-904b-20031339fc37/page/p_1ezjaa2oed',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/b16db949-ec7b-4979-aa89-e1de252116dc/page/p_i155gan27c',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/f7e0be4e-5546-46ce-8aec-e224f1da1496/page/p_cxdlxder3c',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/7e4cd784-5eb8-41ee-91e8-e128c0341fb6/page/p_12wwvq36dd',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/9452ebe5-e2ef-4d8d-9686-bd02943eee27/page/p_5q3z0tmyed',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/9452ebe5-e2ef-4d8d-9686-bd02943eee27/page/p_tqvp3guzed',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/linklogo.png',
'name': 'App LINK',
'link': 'https://www.appsheet.com/start/28785d83-62f3-4ec6-8ddd-2780d413dfa7',
'userAccess': ['NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/timelogo.png',
'name': 'App TIME',
'link': 'https://www.appsheet.com/start/bd11e9cb-0d5c-423f-bead-3c07f1eae0a3',
'userAccess': ['NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/checklogo.png',
'name': 'App CHECK',
'link': 'https://www.appsheet.com/start/38c43e28-1170-4234-95b7-3ea57358a3fa',
'userAccess': ['NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Giám sát',
'link': 'https://lookerstudio.google.com/reporting/facbf6f6-75c8-4ce4-a4ae-3fe7d8617acc/page/p_4aim8v2qbd',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề BC',
'link': 'https://lookerstudio.google.com/reporting/facbf6f6-75c8-4ce4-a4ae-3fe7d8617acc/page/p_els3diiled',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/reporting/e82ebf09-9f40-4377-a7a3-1c9406bf11b2/page/p_1ezjaa2oed',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Theo dõi chấm công',
'link': 'https://lookerstudio.google.com/reporting/0f807fef-1a12-4348-afc5-2e2ff8086362/page/p_3240qu9x7c',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Các BP quẹt thẻ',
'link': 'https://lookerstudio.google.com/reporting/12f29e68-e948-4f34-a254-3ace12cbe9ae/page/p_cxdlxder3c',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Vận hành Máy móc',
'link': 'https://lookerstudio.google.com/reporting/ed64e39f-1a21-4de2-98ed-79fc41361cae/page/p_4aim8v2qbd',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Phương án xử lý Nhân sự',
'link': 'https://lookerstudio.google.com/reporting/facbf6f6-75c8-4ce4-a4ae-3fe7d8617acc/page/p_5q3z0tmyed',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của GS',
'link': 'https://lookerstudio.google.com/reporting/facbf6f6-75c8-4ce4-a4ae-3fe7d8617acc/page/p_tqvp3guzed',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Kế hoạch tuần của QLDV',
'link': 'https://lookerstudio.google.com/reporting/facbf6f6-75c8-4ce4-a4ae-3fe7d8617acc/page/p_9z3m0anyed',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Tổng hợp vấn đề báo cáo',
'link': 'https://lookerstudio.google.com/u/0/reporting/facbf6f6-75c8-4ce4-a4ae-3fe7d8617acc/page/p_els3diiled',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_gwubweuhjd',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Kiểm tra Giám sát',
'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_ywj997whjd',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_wm5td83hjd',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_qo5uga4hjd',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_7hp57a4hjd',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_put00b4hjd',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_kgf0yc4hjd',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_sxi7rd4hjd',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/zalologo.png',
'name': 'Báo cáo OA hàng ngày',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_zdsuhe4hjd',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_284hog8ecd',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_1cxbqu1hjd',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_3kw9ym3hjd',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_8gfi8t3hjd',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_oljsh73hjd',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_xfamoa4hjd',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_yy9hed4hjd',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Nhân sự thiếu',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_cb91bh4hjd',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_6w19kr9hjd',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_jwkq7s9hjd',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_itykqt9hjd',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_jzhvfu9hjd',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_zpxz3u9hjd',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_b2hnov9hjd',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_fur58v9hjd',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Báo cáo Service',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_imdskw8hjd',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0045','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0064','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0129','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0126','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0729','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM0198','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
  ];
Future<void> _handleUrlOpen(String url, String title) async {
  final Uri uri = Uri.parse(url);
  
  // List of domains that should open in system browser
  final browserDomains = [
    'zalo.me',
    'facebook.com',
    'tiktok.com',
    'instagram.com',
    'hoanmykleanco.com'
  ];

  bool shouldOpenInBrowser = browserDomains.any((domain) => url.contains(domain));

  if (shouldOpenInBrowser) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } else {
    showWebViewDialog(context, url, title);
  }
}
void showWebViewDialog(BuildContext context, String url, String title) async {
  if (await WebviewWindow.isWebviewAvailable()) {
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: title,
        titleBarTopPadding: Platform.isMacOS ? 20 : 0,
        windowWidth: 1024,
        windowHeight: 768,
      ),
    );

    webview.launch(url);

  } else {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text('Webview is not available on this system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
 List<Map<String, dynamic>> _getFilteredGridItems(String? employeeId) {
    if (employeeId == null) return [];
    
    return gridData.where((item) {
      if (!item.containsKey('userAccess')) return true;
      List<String> allowedUsers = (item['userAccess'] as List).cast<String>();
      return allowedUsers.isEmpty || allowedUsers.contains(employeeId);
    }).toList();
  }
@override
Widget build(BuildContext context) {
  super.build(context);
  
  return Consumer<UserState>(
    builder: (context, userState, child) {
      final employeeId = userState.currentUser?['employee_id'];
      _filteredItems ??= _getFilteredGridItems(employeeId);
      
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/appbackgrid.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 6.0,
                        crossAxisSpacing: 6.0,
                        childAspectRatio: 1 / 0.8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _filteredItems!.length) return null;
                          return GridItem(
                            itemData: _filteredItems![index],
                            onTap: () => _handleUrlOpen(
                              _filteredItems![index]['link']!,
                              _filteredItems![index]['name']!,
                            ),
                          );
                        },
                        childCount: _filteredItems!.length,
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
}
class GridItem extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final VoidCallback onTap;

  const GridItem({Key? key, required this.itemData, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 247, 247, 247).withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              itemData['icon']!,
              width: 65.0,
              height: 65.0,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                itemData['name']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18.0,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}