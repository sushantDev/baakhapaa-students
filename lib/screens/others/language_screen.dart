import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../../widgets/header.dart';

class LanguageSelectorScreen extends StatelessWidget {
  static const routeName = '/language-selector-screen';

  const LanguageSelectorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: header(
        context: context,
        titleText:
            AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
      ),
      body: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? const Color.fromARGB(255, 9, 9, 9)
                  : const Color.fromARGB(255, 85, 69, 69),
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF082032)
                  : Colors.white,
            ],
          ),
        ),
        child: ListView.builder(
          itemCount: languageProvider.supportedLocales.length,
          itemBuilder: (context, index) {
            final locale = languageProvider.supportedLocales[index];
            final languageName =
                languageProvider.languageNames[locale.languageCode] ??
                    locale.languageCode;
            final isSelected = languageProvider.currentLocale.languageCode ==
                locale.languageCode;

            return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : const Color.fromARGB(255, 230, 229, 200),
                    child: Icon(Icons.language,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : const Color.fromARGB(255, 172, 76, 175)),
                  ),
                  title: Text(
                    languageName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                  onTap: () async {
                    await languageProvider.changeLanguage(locale.languageCode);
                    Navigator.of(context).pop();
                  },
                ));
          },
        ),
      ),
    );
  }
}
