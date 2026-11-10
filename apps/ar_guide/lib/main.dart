// Safe Japan: the app (lib/app/app_shell.dart). The deep link from the web mock still opens the AR screen directly:
//   tasuku-ar://guide?turn=right&dist=12&dest=Hill%20Park&lang=en&bearing=80
// See README.md.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_shell.dart';
import 'app/i18n/i18n.dart';
import 'app/theme.dart';
import 'src/guide_params.dart';
import 'src/guide_screen.dart';
import 'src/platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedLang();
  registerFontLicenses();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ArGuideApp());
}

class ArGuideApp extends StatefulWidget {
  const ArGuideApp({super.key});

  @override
  State<ArGuideApp> createState() => _ArGuideAppState();
}

class _ArGuideAppState extends State<ArGuideApp> {
  /// Set when the app was opened by a deep link: the AR screen is shown instead of the app.
  GuideParams? _linkParams;

  @override
  void initState() {
    super.initState();
    NativeBridge.onLink(_applyLink);
    NativeBridge.initialLink().then((link) {
      if (link != null) _applyLink(link);
    });
  }

  void _applyLink(String link) {
    if (!mounted) return;
    setState(() => _linkParams = GuideParams.fromUri(Uri.tryParse(link)));
  }

  @override
  Widget build(BuildContext context) {
    final linkParams = _linkParams;
    return MaterialApp(
      title: 'Safe Japan',
      debugShowCheckedModeBanner: false,
      theme: tkMaterialTheme(),
      home: linkParams == null
          ? const AppShell()
          : TkFontScope(lang: linkParams.lang, child: GuideScreen(params: linkParams)),
    );
  }
}
