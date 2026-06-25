import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction.dart';
import '../services/app_config.dart';

/// Baidu OCR token management
class BaiduOcrAuth {
  static final String apiKey = AppConfig.baiduOcrApiKey;
  static final String secretKey = AppConfig.baiduOcrSecretKey;
  static String? _accessToken;

  static Future<String> getAccessToken() async {
    if (_accessToken != null) return _accessToken!;
    final resp = await http.post(Uri.parse(
        'https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=$apiKey&client_secret=$secretKey'));
    final data = json.decode(resp.body);
    _accessToken = data['access_token'];
    return _accessToken!;
  }
}

class OcrTransaction {
  final String merchant;
  final double amount;
  final String type;
  final DateTime date;
  OcrTransaction({
    required this.merchant,
    required this.amount,
    required this.type,
    required this.date,
  });
}

class BaiduBillImporter {
  static Future<List<OcrTransaction>> recognizeBill(String imagePath) async {
    final token = await BaiduOcrAuth.getAccessToken();
    final file = File(imagePath);
    final imgB64 = base64Encode(await file.readAsBytes());
    final resp = await http.post(
      Uri.parse(
          'https://aip.baidubce.com/rest/2.0/ocr/v1/accurate_basic?access_token=$token'),
      body: {'image': imgB64, 'language_type': 'CHN_ENG'},
    );
    final data = json.decode(resp.body);
    if (data['error_code'] != null) {
      throw Exception('OCR错误: ${data['error_msg']}');
    }
    final words =
        (data['words_result'] as List).map((r) => r['words'] as String).toList();
    final text = words.join(' ');
    if (text.contains('搜索交易记录') || text.contains('支付宝')) {
      return _parseAlipay(words);
    } else if (text.contains('全部账单') || text.contains('查找交易')) {
      return _parseWechat(words);
    } else {
      throw Exception('无法识别账单类型，请确认是支付宝或微信账单截图');
    }
  }

  /// 退款关键词（跳过这些条目）
  static final List<String> _refundKeywords = [
    '退款', '退货', '已退款', '取消', '已撤', '退回', '付款退回',
    '交易关闭', '关闭交易', '撤销', '冲正',
  ];

  static List<OcrTransaction> _parseAlipay(List<String> words) {
    final results = <OcrTransaction>[];
    int i = 0;
    while (i < words.length) {
      if (RegExp(r'^-?(\d{1,3}(,\d{3})*|\d+)\.\d{2}$').hasMatch(words[i]) ||
          words[i].startsWith('-')) {
        final amt = double.tryParse(words[i].replaceAll(',', ''));
        if (amt == null) {
          i++;
          continue;
        }

        // 扫描前后字词判断是否为退款
        bool isRefund = false;
        for (int j = i - 6; j <= i + 3 && j < words.length; j++) {
          if (j < 0) continue;
          for (final kw in _refundKeywords) {
            if (words[j].contains(kw)) { isRefund = true; break; }
          }
          if (isRefund) break;
        }
        if (isRefund) { i++; continue; }

        String merchant = '';
        String dateStr = '';
        int lookBack = i - 1;
        final beforeWords = <String>[];
        while (lookBack >= 0 && beforeWords.length < 6) {
          final w = words[lookBack];
          if (w == '淘' || w == '天猫' || w == '王猫') break;
          if (RegExp(r'^\d{2}-\d{2}$').hasMatch(w)) {
            beforeWords.add(w);
            break;
          }
          beforeWords.add(w);
          lookBack--;
        }
        for (final w in beforeWords.reversed) {
          if (RegExp(r'^\d{2}-\d{2}$').hasMatch(w)) {
            dateStr = w;
          } else if (!['等待确认收货', '交易关闭', '已完成', '进行中', ''].contains(w) &&
              !w.contains('元') && !w.contains('已省') && merchant.isEmpty) {
            merchant = w;
          }
        }
        final type = words[i].startsWith('-') ? 'expense' : 'income';
        DateTime txDate = DateTime.now();
        if (dateStr.isNotEmpty) {
          final parts = dateStr.split('-');
          txDate = DateTime(2026, int.parse(parts[0]), int.parse(parts[1]));
        }
        results.add(OcrTransaction(
            merchant: merchant, amount: amt.abs(), type: type, date: txDate));
      }
      i++;
    }
    return results;
  }

  static List<OcrTransaction> _parseWechat(List<String> words) {
    final results = <OcrTransaction>[];
    int i = 0;
    while (i < words.length) {
      if (RegExp(r'^-?\d+\.\d{2}$').hasMatch(words[i])) {
        final amt = double.tryParse(words[i]);
        if (amt == null) { i++; continue; }

        // 微信：正数=退款/收入，负数=支出
        // 扫描前后判断是否退款
        bool isRefund = false;
        if (amt >= 0) {
          // 正数可能是退款或收入，检查关键词
          for (int j = i - 4; j <= i + 4 && j < words.length; j++) {
            if (j < 0) continue;
            for (final kw in _refundKeywords) {
              if (words[j].contains(kw)) { isRefund = true; break; }
            }
            if (isRefund) break;
          }
          // 正数但不是退款→视为收入
          if (!isRefund) { i++; continue; } // 跳过非退款的收入（微信截图主要处理支出）
        }
        if (isRefund) { i++; continue; }

        String merchant = i > 0 ? words[i - 1] : '';
        DateTime txDate = DateTime.now();
        if (i + 1 < words.length) {
          final m = RegExp(r'(\d+)月(\d+)日\s*(\d+)[：:](\d+)')
              .firstMatch(words[i + 1]);
          if (m != null) {
            txDate = DateTime(2026, int.parse(m.group(1)!),
                int.parse(m.group(2)!), int.parse(m.group(3)!), int.parse(m.group(4)!));
          }
        }
        results.add(OcrTransaction(
            merchant: merchant, amount: amt.abs(), type: 'expense', date: txDate));
      }
      i++;
    }
    return results;
  }

  static String inferCategory(String merchant) {
    final map = {
      '餐饮': [
        '冷食', '快餐', '餐厅', '食堂', '面包', '奶茶', '咖啡', '水果', '买菜',
        '外卖', '饿了么', '美团', '肯德基', '麦当劳', '必胜客', '星巴克',
        '超市', '便利店', '零食', '小吃', '卤味', '火锅', '烧烤', '烤肉',
        '日料', '寿司', '海鲜', '家常菜', '面馆', '饺子', '包子', '早餐',
        '午餐', '晚餐', '茶饮', '果汁', '烘焙',
      ],
      '交通': [
        '加油站', '加油', '中石油', '中石化', '公交', '地铁', '打车', '滴滴',
        '停车', '高速', 'e代驾', '代驾', '顺风车', '哈啰', '单车', '共享单车',
        '出租车', '客运', '火车', '高铁', '机票',
      ],
      '购物': [
        '淘宝', '天猫', '拼多多', '京东', '闪魔', '省钱卡', '平台商户',
        '商城', '购物', '百货', '文具', '玩具', '数码', '家电', '手机',
        '电脑', '配件', '箱包', '鞋', '户外', '运动', '家居', '家装',
        '饰品', '手表', '眼镜', '图书', '书', '严选', '唯品会', '苏宁',
        '小米', '华为', '苹果', '品牌',
      ],
      '娱乐': [
        '电影', '游戏', 'KTV', '旅游', '门票', '视频', '音乐', '会员',
        '直播', '打赏', '动漫', '小说', '健身', '游泳', '球馆',
      ],
      '居住': [
        '房租', '水电', '物业', '装修', '家装', '家具', '灯具', '窗帘',
        '床', '沙发', '家电', '空调', '冰箱', '洗衣机', '热水器',
      ],
      '通讯': [
        '话费', '流量', '宽带', '移动', '联通', '电信', '腾讯', '腾讯云',
      ],
      '医疗': [
        '医院', '看病', '药', '体检', '医保', '诊所', '牙科', '眼科',
        '中药', '药店', '大药房',
      ],
      '人情': [
        '红包', '转账', '借', '礼金', '随礼', '份子', '生日', '礼物',
      ],
      '服饰': [
        '衣服', '服装', '鞋', '帽子', '围巾', '包', '饰品', '美妆',
        '护肤品', '化妆品', '香水',
      ],
      '日用品': [
        '日用品', '纸巾', '洗护', '洗衣', '清洁', '收纳', '厨房',
        '浴室', '牙刷', '牙膏', '毛巾',
      ],
      '充值': [
        '充值', '缴费', '会员', '年卡', 'VIP', '订阅', '续费',
      ],
    };
    for (final entry in map.entries) {
      for (final kw in entry.value) {
        if (merchant.contains(kw)) return entry.key;
      }
    }
    return '其他';
  }
}

class ScreenshotImportPage extends StatelessWidget {
  const ScreenshotImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('截图导入')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.image_outlined, size: 80, color: Color(0xFF009688)),
          const SizedBox(height: 20),
          const Text('选择账单截图',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            '支持支付宝账单截图和微信账单截图\n导入后将自动识别并批量添加到记账本',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => _goToPicker(context),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('从相册选择截图', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => _goToPicker(context),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('拍照导入', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF009688),
              side: const BorderSide(color: Color(0xFF009688)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ],
      ),
    );
  }

  void _goToPicker(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _ImagePickerPage()));
  }
}

class _ImagePickerPage extends StatefulWidget {
  const _ImagePickerPage({super.key});
  @override
  State<_ImagePickerPage> createState() => _ImagePickerPageState();
}

class _ImagePickerPageState extends State<_ImagePickerPage> {
  bool _loading = false;
  List<OcrTransaction> _results = [];
  String? _error;
  Set<int> _selectedIndexes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        if (mounted) setState(() => _error = '未选择图片');
        return;
      }
      await processImage(image.path);
    } catch (e) {
      if (mounted) setState(() => _error = '选择图片失败: $e');
    }
  }

  Future<void> processImage(String imagePath) async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final transactions = await BaiduBillImporter.recognizeBill(imagePath);
      if (mounted) {
        setState(() {
          _results = transactions;
          _selectedIndexes = Set.from(List.generate(transactions.length, (i) => i));
          _loading = false;
        });
        if (transactions.isEmpty) {
          setState(() => _error = '未能从图片中识别到账单信息');
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = '识别失败: $e'; _loading = false; });
    }
  }

  void _importSelected() {
    if (_selectedIndexes.isEmpty) return;
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    int count = 0;
    for (final idx in _selectedIndexes) {
      final tx = _results[idx];
      provider.addTransaction(Transaction(
        type: tx.type,
        amount: tx.amount,
        category: BaiduBillImporter.inferCategory(tx.merchant),
        note: tx.merchant,
        date: tx.date,
      ));
      count++;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已成功导入 $count 条账单'),
          backgroundColor: const Color(0xFF4CAF50), duration: const Duration(seconds: 2)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('截图识别'),
        actions: [
          if (_results.isNotEmpty)
            TextButton(
              onPressed: _importSelected,
              child: const Text('导入选中',
                  style: TextStyle(color: Color(0xFF009688), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在识别账单...')],
      ));
    }
    if (_error != null && _results.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          ],
        ),
      ));
    }
    if (_results.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('未识别到账单', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        ],
      ));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFE0F2F1),
          child: Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: Color(0xFF009688)),
              const SizedBox(width: 8),
              Text('识别到 ${_results.length} 条账单，点击取消勾选不需要的条目',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF00796B))),
            ],
          ),
        ),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final tx = _results[i];
            final selected = _selectedIndexes.contains(i);
            final dateStr = DateFormat('MM月dd日').format(tx.date);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) _selectedIndexes.remove(i);
                else _selectedIndexes.add(i);
              }),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? const Color(0xFF009688) : Colors.grey[200]!,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? const Color(0xFF009688) : Colors.grey[400]),
                  title: Text(tx.merchant, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                  trailing: Text('${tx.type == 'income' ? '+' : '-'}¥${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: tx.type == 'income' ? const Color(0xFFFF9800) : const Color(0xFFE53935))),
                ),
              ),
            );
          },
        )),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedIndexes.isNotEmpty ? _importSelected : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('导入选中的 ${_selectedIndexes.length} 条账单', style: const TextStyle(fontSize: 16)),
            ),
          ),
        )),
      ],
    );
  }
}

/// No external path import needed - user selects from phone gallery
