import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import 'screenshot_import.dart';
import 'excel_import_page.dart';

class ImportExportPage extends StatelessWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入导出'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 导入 ─────────────────
          _SectionTitle('导入'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _ImportItem(
                  title: 'Excel账单导入',
                  subtitle: '支持微信、支付宝以及模板Excel文件导入',
                  icon: Icons.table_chart_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExcelImportPage())),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _ImportItem(
                  title: '微信截图导入',
                  subtitle: '截取支付宝微信账单，文字识别导入',
                  icon: Icons.image_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenshotImportPage())),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _ImportItem(
                  title: '支付宝截图导入',
                  subtitle: '截取支付宝微信账单，文字识别导入',
                  icon: Icons.image_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenshotImportPage())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(title,
          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
    );
  }
}

class _ImportItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ImportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF009688), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),

                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
