import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-launch tutorial. Shown once, then skipped on subsequent launches
/// (gated by SharedPreferences). Skippable by the user at any slide.
///
/// Designed to be self-contained — does not depend on Riverpod or any
/// app-specific provider; only reads/writes a single SharedPreferences key.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  /// Called when the user finishes (or skips) onboarding.
  final VoidCallback onFinished;

  static const String _kSeenKey = 'onboarding_v1_seen';

  /// Returns true if the user has already seen the onboarding flow.
  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      icon: Icons.waving_hand_outlined,
      title: 'ברוכה הבאה ליומן תזכורות!',
      body: 'אפליקציה פשוטה להגדרת תזכורות, מעקב אחר הלוח העברי, '
          'וצפייה בחגים ובאירועים. הכל בעברית, גם בלי אינטרנט.',
    ),
    _SlideData(
      icon: Icons.notifications_active_outlined,
      title: 'אישור התראות',
      body: 'בלחיצה על "סיימתי", המערכת תבקש הרשאה לשליחת התראות. '
          'אשרי כדי שהתזכורות שלך יעבדו. בנוסף, ייתכן שתוצג בקשה לחסוך '
          'באופטימיזציית סוללה — חשוב לאשר גם את זה.',
    ),
    _SlideData(
      icon: Icons.cloud_outlined,
      title: 'סנכרון בין מכשירים (לא חובה)',
      body: 'אם תרצי שהתזכורות יסונכרנו בין הטלפון למחשב, היכנסי להגדרות → '
          'סנכרון ענן והתחברי לחשבון Google. הכל פרטי — רק את רואה את הנתונים.',
    ),
    _SlideData(
      icon: Icons.add_circle_outline,
      title: 'מוכנה!',
      body: 'לחיצה על כפתור ה-+ למטה תפתח טופס הוספה. אפשר לקבוע תאריך, '
          'שעה, חזרה (יומי/חודשי/שנתי), קטגוריה וצליל. בהצלחה!',
    ),
  ];

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _index == _slides.length - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('דלג'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              s.icon,
                              size: 64,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final selected = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: selected ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isLast ? 'סיימתי' : 'הבא',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}
