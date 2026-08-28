import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../services/twitter_rankings/twitter_site_config.dart';
import '../../../widgets/bouncing_button.dart';
import '../../../widgets/frosted_glass.dart';

class TwitterSiteDropdown extends StatelessWidget {
  final TwitterSiteConfig currentSite;
  final ValueChanged<TwitterSiteConfig> onSiteSelected;

  const TwitterSiteDropdown({
    super.key,
    required this.currentSite,
    required this.onSiteSelected,
  });

  void _showSiteSelectionSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '选择 Twitter 排行榜站点',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '共 ${TwitterSiteConfig.allSites.length} 个站点',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Sites List
              Flexible(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: TwitterSiteConfig.allSites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, index) {
                    final site = TwitterSiteConfig.allSites[index];
                    final isSelected = site.id == currentSite.id;

                    return BouncingButton(
                      onTap: () {
                        Navigator.pop(ctx);
                        onSiteSelected(site);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? site.themeColor.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected
                              ? Border.all(color: site.themeColor.withValues(alpha: 0.4), width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: site.themeColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                site.icon,
                                color: site.themeColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        site.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? site.themeColor : null,
                                        ),
                                      ),
                                      if (site.isAnimeOnly) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF4081).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            '二次元',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFFF4081),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    site.description,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: site.themeColor,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncingButton(
      onTap: () => _showSiteSelectionSheet(context),
      child: FrostedGlass(
        borderRadius: 14,
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: isDark ? const Color(0x992C2C2E) : Colors.white.withValues(alpha: 0.85),
        borderColor: currentSite.themeColor.withValues(alpha: 0.35),
        borderWidth: 1.2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentSite.icon,
              size: 13,
              color: currentSite.themeColor,
            ),
            const SizedBox(width: 5),
            Text(
              currentSite.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: currentSite.themeColor,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              CupertinoIcons.chevron_down,
              size: 11,
              color: currentSite.themeColor.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
