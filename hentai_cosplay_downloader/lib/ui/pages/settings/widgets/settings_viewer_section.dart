import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';

class SettingsViewerSection extends StatelessWidget {
  const SettingsViewerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prov = context.watch<SettingsProvider>();
    final preloadCount = prov.config.photoPreloadCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '看图与浏览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '图片预加载数量',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$preloadCount 张',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '较低数值可节省内存防止闪退，较高数值提升滑动流畅度',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('3', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: CupertinoSlider(
                      value: preloadCount.toDouble(),
                      min: 3,
                      max: 10,
                      divisions: 7,
                      onChanged: (val) {
                        prov.setPhotoPreloadCount(val.toInt());
                      },
                    ),
                  ),
                  const Text('10', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
