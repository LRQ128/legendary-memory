import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/app_config.dart';

/// Parse Chinese voice input into transaction fields.
class VoiceTransactionParser {
  static const _expenseKeywords = [
    '支出', '花了', '花掉', '消费', '付款', '买了', '购买',
    '打车', '吃饭', '买', '付',
  ];
  static const _incomeKeywords = [
    '收入', '收到', '赚了', '工资', '奖金',
  ];

  /// 收入类关键词 → 收入分类（与 AccountingProvider.incomeCategories 一致）
  static const Map<String, List<String>> _incomeCategoryMap = {
    '工资': ['工资', '薪水'],
    '奖金': ['奖金', '年终奖', '绩效', '提成'],
    '理财': ['理财', '利息', '收益', '投资', '基金', '股票'],
    '兼职': ['兼职', '副业', '外快', '零工'],
  };

  /// 支出类关键词 → 支出分类
  static const _expenseCategoryMap = {
    '餐饮': ['吃饭', '食堂', '外卖', '奶茶', '咖啡', '水果', '买菜', '餐饮', '冷食', '快餐', '早餐', '午餐', '晚餐', '零食', '小吃', '面包', '饮料', '夜宵', '烧烤', '火锅', '酒', '矿泉水', '水'],
    '交通': ['打车', '加油', '公交', '地铁', '滴滴', '停车', '火车', '交通', '出租'],
    '购物': ['买', '淘宝', '京东', '拼多多', '超市', '购物', '闪魔', '网购'],
    '娱乐': ['电影', '游戏', '娱乐', '旅游', 'KTV', '酒吧', '健身'],
    '居住': ['房租', '水电', '物业', '居住', '装修', '燃气', '暖气'],
    '通讯': ['话费', '流量', '宽带', '通讯', '腾讯', '会员', '缴费', '手机'],
    '医疗': ['医院', '看病', '医疗', '药', '诊所'],
    '教育': ['课程', '学习', '教育', '培训', '书', '教材'],
    '人情': ['红包', '随礼', '请客', '送礼'],
    '服饰': ['衣服', '鞋', '包', '首饰', '穿搭', '配饰'],
    '日用品': ['日用', '日用品', '洗衣', '洗发', '纸巾'],
  };

  /// 中文数字 → 阿拉伯数字（支持"十百千万"组合，如"十五""二百五""十块"）
  /// 注意：用 allMatches 取最后一个中文数字段（金额通常在句末），
  /// 避免"零食"的"零"被误匹配。
  static double? _parseChineseNumber(String text) {
    const cnNum = <String, int>{
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
      '两': 2,
    };
    const cnUnit = {'十': 10, '百': 100, '千': 1000, '万': 10000};

    // 先尝试匹配纯阿拉伯数字（含小数点）
    final digitMatch = RegExp(r'\d+(\.\d{1,2})?').firstMatch(text);
    if (digitMatch != null) {
      return double.tryParse(digitMatch.group(0)!);
    }

    // 用 allMatches 找所有中文数字段，取最后一个（金额在句末）
    final cnMatches = RegExp(r'[零一二三四五六七八九十百千万两半]+').allMatches(text);
    if (cnMatches.isEmpty) return null;

    // 取最后一段（跳过开头的"零"，如"零食"的"零"）
    String cnStr = '';
    for (final m in cnMatches) {
      final s = m.group(0)!;
      // 跳过纯"零"的匹配（常见于"零食""零钱"等词开头）
      if (s == '零') continue;
      cnStr = s;
    }
    // 如果全是"零"，取最后一个
    if (cnStr.isEmpty) {
      cnStr = cnMatches.last.group(0)!;
    }

    if (cnStr.isEmpty) return null;
    if (cnStr == '半') return 0.5;

    int result = 0;
    int current = 0;
    bool hasUnit = false;

    for (int i = 0; i < cnStr.length; i++) {
      final char = cnStr[i];
      if (cnNum.containsKey(char)) {
        current = cnNum[char]!;
        hasUnit = false;
      } else if (cnUnit.containsKey(char)) {
        final unit = cnUnit[char]!;
        if (current == 0 && !hasUnit) current = 1;
        if (unit >= 10000) {
          result = (result + current) * unit;
          current = 0;
        } else {
          result += current * unit;
          current = 0;
        }
        hasUnit = true;
      }
    }
    result += current;
    return result > 0 ? result.toDouble() : null;
  }

  static Map<String, dynamic> parse(String input) {
    final text = input.trim();
    String type = 'expense';
    String category = '其他';
    String note = '';
    double amount = 0;

    for (final kw in _incomeKeywords) {
      if (text.contains(kw)) { type = 'income'; break; }
    }

    // 提取金额：先试阿拉伯数字，再试中文数字
    final parsedAmount = _parseChineseNumber(text);
    if (parsedAmount != null) amount = parsedAmount;

    // 提取备注：去掉金额和关键词后的纯文字
    note = text;
    note = note.replaceAll(RegExp(r'[零一二三四五六七八九十百千万两半]+'), '');
    note = note.replaceAll(RegExp(r'\d+(\.\d{1,2})?'), '');
    note = note.replaceAll(RegExp(r'块|块钱|元钱?|毛'), '');
    for (final kw in [..._expenseKeywords, ..._incomeKeywords]) {
      note = note.replaceAll(kw, '');
    }
    note = note.replaceAll(RegExp(r'[花了花掉消费了付了买了支付了转账了收了赚了]'), '');
    note = note.replaceAll(RegExp(r'[的了我吧呢啊呀,.。，！!？?]'), '');
    note = note.trim();
    if (note.isEmpty && amount > 0) note = type == 'income' ? '收入' : '支出';

    // Determine category from text — 收入用收入类别映射，支出用支出类别映射
    if (type == 'income') {
      for (final entry in _incomeCategoryMap.entries) {
        for (final kw in entry.value) {
          if (text.contains(kw)) { category = entry.key; break; }
        }
        if (category != '其他') break;
      }
    } else {
      for (final entry in _expenseCategoryMap.entries) {
        for (final kw in entry.value) {
          if (text.contains(kw)) { category = entry.key; break; }
        }
        if (category != '其他') break;
      }
    }

    return {
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'raw': input,
    };
  }
}

/// Show dialog for manual text input (short tap).
Future<Map<String, dynamic>?> showManualVoiceInput(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('输入记账内容'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '例如：吃饭花了25块',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('确认'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null && result.isNotEmpty) {
    return VoiceTransactionParser.parse(result);
  }
  return null;
}

/// Speech recognition via Baidu ASR API (短语音识别).
class _BaiduASR {
  static final String _apiKey = AppConfig.baiduAsrApiKey;
  static final String _secretKey = AppConfig.baiduAsrSecretKey;
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  static Future<String> _getAccessToken() async {
    // Return cached token if still valid
    if (_accessToken != null && _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final url = Uri.parse(
        'https://aip.baidubce.com/oauth/2.0/token'
        '?grant_type=client_credentials'
        '&client_id=$_apiKey'
        '&client_secret=$_secretKey');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      _accessToken = data['access_token'];
      // Token expires in 30 days, cache for 29 days
      _tokenExpiry = DateTime.now().add(const Duration(days: 29));
      debugPrint('Baidu ASR token refreshed');
      return _accessToken!;
    }
    throw Exception('Failed to get Baidu token: ${res.body}');
  }

  /// Recognize speech from a WAV file path.
  /// Uses Baidu Short Speech Recognition API (server_api, dev_pid=1537).
  static Future<String> recognize(String audioPath) async {
    final token = await _getAccessToken();
    final file = File(audioPath);
    if (!await file.exists()) throw Exception('Audio file not found: $audioPath');

    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);
    final audioLen = bytes.length;

    // 百度短语音识别 v2 API
    // token和cuid都放body，URL放access_token
    final url = Uri.parse('https://vop.baidu.com/server_api');
    final body = json.encode({
      'format': 'wav',
      'rate': 16000,
      'channel': 1,
      'cuid': 'daily_accounting',
      'token': token,
      'speech': base64Audio,
      'len': audioLen,
      'dev_pid': 1537,
    });

    debugPrint('Baidu ASR calling server_api...');
    final res = await http.post(url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('Baidu ASR response: ${res.body}');
    final data = json.decode(res.body);

    if (data['err_no'] == 0 && data['result'] != null) {
      final results = List<String>.from(data['result']);
      final recognized = results.join('');
      if (recognized.isNotEmpty) return recognized;
    }

    throw Exception('ASR failed (${data['err_no']}): ${data['err_msg'] ?? 'unknown'}');
  }
}

/// Speech recording button with long-press → record, release → recognize, swipe-up → cancel.
class SpeechRecordButton extends StatefulWidget {
  final void Function(Map<String, dynamic> result) onResult;

  const SpeechRecordButton({super.key, required this.onResult});

  @override
  State<SpeechRecordButton> createState() => _SpeechRecordButtonState();
}

class _SpeechRecordButtonState extends State<SpeechRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordPath;
  bool _isRecording = false;
  bool _cancelled = false;
  bool _isProcessing = false;
  double _swipeOffset = 0;
  double _startY = 0;

  @override
  void initState() { super.initState(); }

  Future<String> _getTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音'), duration: Duration(seconds: 2)));
        return;
      }

      final path = await _getTempPath();
      _recordPath = path;

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      if (mounted) {
        setState(() { _isRecording = true; _cancelled = false; _swipeOffset = 0; });
      }
    } catch (e) {
      debugPrint('Record start error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败: $e'), duration: const Duration(seconds: 2)));
      }
    }
  }

  /// 结束录音 → 识别（或取消时清理）
  Future<void> _finishRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Record stop error: $e');
    }

    if (!mounted) return;

    // 上滑取消 → 删文件不识别
    if (_cancelled) {
      setState(() { _isRecording = false; _cancelled = false; });
      if (_recordPath != null) { try { await File(_recordPath!).delete(); } catch (_) {} }
      _recordPath = null;
      return;
    }

    // 正常结束 → 百度 ASR 识别
    if (_recordPath != null) {
      setState(() { _isRecording = false; _isProcessing = true; });

      try {
        final recognizedText = await _BaiduASR.recognize(_recordPath!);
        debugPrint('ASR result: $recognizedText');

        // Clean up temp file
        try { await File(_recordPath!).delete(); } catch (_) {}
        _recordPath = null;

        if (!mounted) return;

        if (recognizedText.isNotEmpty) {
          final parsed = VoiceTransactionParser.parse(recognizedText);
          widget.onResult(parsed);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已识别: "$recognizedText"'),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('ASR error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音识别失败: $e'), duration: const Duration(seconds: 3)));
        }
      }

      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    } else {
      setState(() { _isRecording = false; });
    }
  }

  /// 短按 → 手动输入
  void _onTap() {
    if (_isProcessing) return;
    showManualVoiceInput(context).then((result) {
      if (result != null) widget.onResult(result);
    });
  }

  /// 长按开始 → 启动录音，记录起始位置
  void _onLongPressStart(LongPressStartDetails details) async {
    if (_isProcessing) return;
    _startY = details.globalPosition.dy;
    await _startRecording();
  }

  /// 手指移动 → 根据全局Y偏移判断是否上滑取消
  void _onPointerMove(PointerMoveEvent event) {
    if (!_isRecording) return;
    final dy = event.position.dy - _startY;
    setState(() {
      _swipeOffset = dy;
      if (dy < -60 && !_cancelled) {
        _cancelled = true;
      } else if (dy >= -40 && _cancelled) {
        _cancelled = false;
      }
    });
  }

  /// 手指抬起 → 结束录音
  void _onPointerUp(PointerUpEvent event) {
    _finishRecording();
  }

  /// 手指取消（系统中断）→ 兜底结束录音
  void _onPointerCancel(PointerCancelEvent event) {
    _finishRecording();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Cancel/Processing indicator
        if (_isRecording)
          Positioned(
            top: -80 + _swipeOffset.clamp(-80, 0),
            child: Column(children: [
              Icon(Icons.arrow_drop_up,
                color: _cancelled ? Colors.red : Colors.grey[400], size: 28),
              Text(_cancelled ? '松开取消' : '上滑取消',
                style: TextStyle(fontSize: 12,
                  color: _cancelled ? Colors.red : Colors.grey[400])),
            ]),
          ),

        // Processing indicator
        if (_isProcessing)
          Positioned(
            top: -40,
            child: Column(children: [
              const SizedBox(height: 8),
              Text('识别中...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),

        // FAB button
        Listener(
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            onTap: _onTap,
            onLongPressStart: _onLongPressStart,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isRecording ? 64 : 56,
            height: _isRecording ? 64 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isProcessing
                  ? Colors.grey
                  : _isRecording
                      ? (_cancelled ? Colors.red[400] : Colors.orange)
                      : const Color(0xFF4CAF50),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.orange : const Color(0xFF4CAF50)).withOpacity(0.4),
                  blurRadius: _isRecording ? 20 : 8,
                  spreadRadius: _isRecording ? 6 : 1,
                ),
              ],
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_isRecording ? Icons.graphic_eq : Icons.mic,
                    color: Colors.white, size: 28),
          ),
          ),
        ),

        // Recording indicator dots
        if (_isRecording)
          Positioned(
            bottom: -30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(Colors.orange[300]!, 300),
                _dot(Colors.orange[400]!, 500),
                _dot(Colors.orange[500]!, 700),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(Color color, int delayMs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _PulsingDot(color: color, delayMs: delayMs),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final int delayMs;
  const _PulsingDot({required this.color, required this.delayMs});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: 6 + _controller.value * 4,
          height: 6 + _controller.value * 4,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
