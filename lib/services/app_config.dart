/// 应用配置常量
/// 将硬编码的 API 密钥抽取到此文件，方便统一管理和替换。
/// 生产环境建议使用 --dart-define 编译参数注入，不要硬编码在源码中。
class AppConfig {
  AppConfig._();

  // ── Supabase ──
  static const String supabaseUrl =
      'https://mztpylfnowmvigjtlshu.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16dHB5bGZub3dtdmlnanRsc2h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMjczMDQsImV4cCI6MjA5NzgwMzMwNH0.b_iSbc_CxZyqqYE5A92ezHM4MA-sMUc2VsjEtxIkv_Q';

  // ── Baidu ASR（语音识别）─
  static const String baiduAsrApiKey = 'oHe9j89zx42RENMWBGXspGSf';
  static const String baiduAsrSecretKey = '7WkDoFMOUcZEEU9H3M61yaSntYjzKqR5';

  // ── Baidu OCR（截图识别）─
  static const String baiduOcrApiKey = 'cnmeORnqV4kNswV2zIUUdOWx';
  static const String baiduOcrSecretKey = '33rXO9KGoZ1iw3MhpHRvd4WzhQaSqWak';
}
